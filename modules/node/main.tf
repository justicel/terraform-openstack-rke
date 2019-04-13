# Find image ID from name
data "openstack_images_image_v2" "node" {
  name        = "${var.image_name}"
  most_recent = true
}

# Secondary volume enablement, to count
locals {
  secondary_enable = "${var.secondary_volume_size == 0 ? 0 : 1}"
  primary_enable   = "${var.secondary_volume_size == 0 ? 1 : 0}"
}

# Template file for cloud-init for rancheros
data "template_file" "init" {
  template = "${file("${path.module}/templates/rancheros.tpl")}"

  vars = {
    docker_version = "${var.docker_version}"
  }
}

# Create instance
resource "openstack_compute_instance_v2" "instance" {
  count        = "${var.count * local.primary_enable}"
  name         = "${var.name_prefix}-${format("%03d", count.index)}"
  image_name   = "${var.image_name}"
  config_drive = true
  user_data    = "${data.template_file.init.rendered}"
  flavor_name  = "${var.flavor_name}"
  key_pair     = "${var.os_ssh_keypair}"

  block_device {
    uuid                  = "${data.openstack_images_image_v2.node.id}"
    source_type           = "image"
    boot_index            = 0
    destination_type      = "local"
    delete_on_termination = true
  }

  network {
    name = "${var.network_name}"
  }

  security_groups = ["${var.secgroup_name}"]

  # Try to drain and delete node before downscaling
  provisioner "local-exec" {
    when       = "destroy"
    on_failure = "continue" # when running terraform destroy this provisioner will fail

    environment {
      KUBECONFIG = "./kube_config_cluster.yml"
    }

    command = "kubectl drain ${var.name_prefix}-${format("%03d", count.index)} --delete-local-data --force --ignore-daemonsets && kubectl delete node ${var.name_prefix}-${format("%03d", count.index)}"
  }
}

resource "openstack_compute_instance_v2" "instance_secondary_volume" {
  count        = "${var.count * local.secondary_enable}"
  name         = "${var.name_prefix}-${format("%03d", count.index)}"
  image_name   = "${var.image_name}"
  config_drive = true
  user_data    = "${file("${path.module}/templates/rancheros.tpl")}"
  flavor_name  = "${var.flavor_name}"
  key_pair     = "${var.os_ssh_keypair}"

  block_device {
    uuid                  = "${data.openstack_images_image_v2.node.id}"
    source_type           = "image"
    boot_index            = 0
    destination_type      = "local"
    delete_on_termination = true
  }

  block_device {
    boot_index            = -1
    delete_on_termination = true
    destination_type      = "local"
    source_type           = "blank"
    volume_size           = "${var.secondary_volume_size}"
  }

  network {
    name = "${var.network_name}"
  }

  security_groups = ["${var.secgroup_name}"]

  # Try to drain and delete node before downscaling
  provisioner "local-exec" {
    when       = "destroy"
    on_failure = "continue" # when running terraform destroy this provisioner will fail

    environment {
      KUBECONFIG = "./kube_config_cluster.yml"
    }

    command = "kubectl drain ${var.name_prefix}-${format("%03d", count.index)} --delete-local-data --force --ignore-daemonsets && kubectl delete node ${var.name_prefix}-${format("%03d", count.index)}"
  }
}

# Allocate floating IPs (if required)
resource "openstack_compute_floatingip_v2" "floating_ip" {
  count = "${var.assign_floating_ip ? var.count : 0}"
  pool  = "${var.floating_ip_pool}"
}

# Associate floating IPs (if required)
resource "openstack_compute_floatingip_associate_v2" "associate_floating_ip" {
  count       = "${var.assign_floating_ip ? var.count : 0}"
  floating_ip = "${element(openstack_compute_floatingip_v2.floating_ip.*.address, count.index)}"
  instance_id = "${element(coalescelist(openstack_compute_instance_v2.instance_secondary_volume.*.id, openstack_compute_instance_v2.instance.*.id), count.index)}"
}

# Prepare nodes for RKE
resource null_resource "prepare_nodes" {
  count = "${var.count}"

  triggers {
    instance_id = "${element(coalescelist(openstack_compute_instance_v2.instance_secondary_volume.*.id, openstack_compute_instance_v2.instance.*.id), count.index)}"
  }

  provisioner "remote-exec" {
    inline = ["while ! ls -alh /var/run/docker.sock > /dev/null 2>&1; do sleep 20; done"]
  }

  connection {
    # External
    bastion_host     = "${var.assign_floating_ip && var.ssh_bastion_host == "" ? element(concat(openstack_compute_floatingip_v2.floating_ip.*.address,list("")), count.index) : var.ssh_bastion_host}" # workaround (empty list, no need in TF 0.12)
    bastion_host_key = "${file(var.ssh_key)}"

    # Internal
    host        = "${element(coalescelist(openstack_compute_instance_v2.instance_secondary_volume.*.network.0.fixed_ip_v4, openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4), count.index)}"
    user        = "${var.ssh_user}"
    private_key = "${file(var.ssh_key)}"
  }
}

# RKE node mappings
locals {
  # Workaround for list not supported in conditionals (https://github.com/hashicorp/terraform/issues/12453)
  address_list = ["${split(",", var.assign_floating_ip ? join(",", openstack_compute_floatingip_v2.floating_ip.*.address) : join(",", coalescelist(openstack_compute_instance_v2.instance_secondary_volume.*.network.0.fixed_ip_v4, openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4)))}"]
}

data rke_node_parameter "node_mappings" {
  count = "${var.count}"

  address           = "${element(local.address_list, count.index)}"
  user              = "${var.ssh_user}"
  ssh_key_path      = "${var.ssh_key}"
  internal_address  = "${element(coalescelist(openstack_compute_instance_v2.instance_secondary_volume.*.network.0.fixed_ip_v4, openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4), count.index)}"
  hostname_override = "${element(coalescelist(openstack_compute_instance_v2.instance_secondary_volume.*.name, openstack_compute_instance_v2.instance.*.name), count.index)}"
  role              = "${var.role}"
  labels            = "${var.labels}"
}
