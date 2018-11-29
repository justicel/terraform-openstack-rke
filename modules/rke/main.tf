# Provision RKE
resource rke_cluster "cluster" {

  cloud_provider {
      name = "openstack"
      openstackCloudProvider = {
        global = {
          username = "${var.os_username}"
          password = "${var.os_password}"
          auth-url = "${var.os_auth_url}"
          tenant-id = "${var.os_tenant_id}"
          tenant-name = "${var.os_tenant_name}"
          domain-name = "${var.os_domain_name}"
        }
        block_storage = {
          bs-version = "auto"
          ignore-volume-az = "false"
          trust-device-path = "false"
        }
      }
    }

  nodes_conf = ["${var.node_mappings}"]

  bastion_host = {
    address      = "${var.ssh_bastion_host}"
    user         = "${var.ssh_user}"
    ssh_key_path = "${var.ssh_key}"
    port         = 22
  }

  ingress = {
    provider = "nginx"

    node_selector = {
      node_type = "edge"
    }
  }

  authentication = {
    strategy = "x509"
    sans     = ["${var.kubeapi_sans_list}"]
  }

  ignore_docker_version = "${var.ignore_docker_version}"

  # Workaround: make sure resources are created and deleted in the right order
  provisioner "local-exec" {
    command = "# ${join(",",var.rke_cluster_deps)}"
  }
}

# Write YAML configs
locals {
  api_access       = "https://${element(var.kubeapi_sans_list,0)}:6443"
  api_access_regex = "/https://\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}:6443/"
}

resource local_file "kube_config_cluster" {
  count    = "${var.write_kube_config_cluster ? 1 : 0}"
  filename = "${path.root}/kube_config_cluster.yml"

  # Workaround: https://github.com/rancher/rke/issues/705
  content = "${replace(rke_cluster.cluster.kube_config_yaml, local.api_access_regex, local.api_access)}"
}

resource "local_file" "custer_yml" {
  count    = "${var.write_cluster_yaml ? 1 : 0}"
  filename = "${path.root}/cluster.yml"
  content  = "${rke_cluster.cluster.rke_cluster_yaml}"
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = "${local.api_access}"
  username               = "${rke_cluster.cluster.kube_admin_user}"
  client_certificate     = "${rke_cluster.cluster.client_cert}"
  client_key             = "${rke_cluster.cluster.client_key}"
  cluster_ca_certificate = "${rke_cluster.cluster.ca_crt}"
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = "${local.api_access}"
    client_certificate     = "${rke_cluster.cluster.client_cert}"
    client_key             = "${rke_cluster.cluster.client_key}"
    cluster_ca_certificate = "${rke_cluster.cluster.ca_crt}"
  }
}
