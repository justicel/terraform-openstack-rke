# Provision RKE
resource rke_cluster "cluster" {
  count              = "${var.use_bastion ? 1 : 0}"
  nodes_conf         = ["${var.node_mappings}"]
  kubernetes_version = "${var.kubernetes_version}"
  cluster_name       = "local"
  ssh_agent_auth     = "${var.ssh_agent_auth}"
  ssh_key_path       = "${var.ssh_key}"
  prefix_path        = "/"
  addon_job_timeout  = 30

  monitoring {
    provider = "metrics-server"
  }

  dns {
    provider = "kube-dns"
  }

  authorization {
    mode = "rbac"
  }

  bastion_host = {
    address      = "${var.ssh_bastion_host}"
    user         = "${var.ssh_user}"
    ssh_key_path = "${var.ssh_key}"
    port         = 22
  }

  services_etcd {
    snapshot  = true
    retention = "24h"
    creation  = "6h0s"
  }

  network {
    plugin = "canal"

    options = {
      canal_flannel_backend_type = "vxlan"
    }
  }

  cloud_provider {
    name = "openstack"

    openstack_cloud_config = {
      global = {
        username  = "${var.openstack_username}"
        password  = "${var.openstack_password}"
        auth_url  = "${var.openstack_auth_url}"
        tenant_id = "${var.openstack_tenant_id}"
        region    = "${var.openstack_region}"
      }
    }
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

resource rke_cluster "cluster_no_bastion" {
  count              = "${var.use_bastion ? 0 : 1}"
  nodes_conf         = ["${var.node_mappings}"]
  kubernetes_version = "${var.kubernetes_version}"
  cluster_name       = "local"
  ssh_agent_auth     = "${var.ssh_agent_auth}"
  ssh_key_path       = "${var.ssh_key}"
  prefix_path        = "/"
  addon_job_timeout  = 30

  monitoring {
    provider = "metrics-server"
  }

  dns {
    provider = "kube-dns"
  }

  authorization {
    mode = "rbac"
  }

  services_etcd {
    snapshot  = true
    retention = "24h"
    creation  = "6h0s"
  }

  network {
    plugin = "canal"

    options = {
      canal_flannel_backend_type = "vxlan"
    }
  }

  cloud_provider {
    name = "openstack"

    openstack_cloud_config = {
      global = {
        username  = "${var.openstack_username}"
        password  = "${var.openstack_password}"
        auth_url  = "${var.openstack_auth_url}"
        tenant_id = "${var.openstack_tenant_id}"
        region    = "${var.openstack_region}"
      }
    }
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
  content = "${replace(coalesce(join("", rke_cluster.cluster_no_bastion.*.kube_config_yaml), join("", rke_cluster.cluster.*.kube_config_yaml)), local.api_access_regex, local.api_access)}"
}

resource "local_file" "cluster_yml" {
  count    = "${var.write_cluster_yaml ? 1 : 0}"
  filename = "${path.root}/cluster.yml"
  content  = "${coalesce(join("", rke_cluster.cluster_no_bastion.*.rke_cluster_yaml), join("", rke_cluster.cluster.*.rke_cluster_yaml))}"
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = "${local.api_access}"
  username               = "${coalesce(join("", rke_cluster.cluster_no_bastion.*.kube_admin_user), join("", rke_cluster.cluster.*.kube_admin_user))}"
  client_certificate     = "${coalesce(join("", rke_cluster.cluster_no_bastion.*.client_cert), join("", rke_cluster.cluster.*.client_cert))}"
  client_key             = "${coalesce(join("", rke_cluster.cluster_no_bastion.*.client_key), join("", rke_cluster.cluster.*.client_key))}"
  cluster_ca_certificate = "${coalesce(join("", rke_cluster.cluster_no_bastion.*.ca_crt), join("", rke_cluster.cluster.*.ca_crt))}"
}

# Configure Helm provider
# Workaround: https://github.com/terraform-providers/terraform-provider-helm/issues/148
provider "helm" {
  service_account = "tiller"
  namespace       = "kube-system"
  install_tiller  = false

  kubernetes {
    host                   = "${local.api_access}"
    client_certificate     = "${coalesce(join("", rke_cluster.cluster_no_bastion.*.client_cert), join("", rke_cluster.cluster.*.client_cert))}"
    client_key             = "${coalesce(join("", rke_cluster.cluster_no_bastion.*.client_key), join("", rke_cluster.cluster.*.client_key))}"
    cluster_ca_certificate = "${coalesce(join("", rke_cluster.cluster_no_bastion.*.ca_crt), join("", rke_cluster.cluster.*.ca_crt))}"
  }
}

resource "kubernetes_service_account" "tiller" {
  metadata {
    name      = "tiller"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "tiller" {
  depends_on = ["kubernetes_service_account.tiller"]

  metadata {
    name = "tiller"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind = "User"
    name = "system:serviceaccount:kube-system:tiller"
  }
}

resource null_resource "tiller" {
  depends_on = ["kubernetes_cluster_role_binding.tiller"]

  provisioner "local-exec" {
    environment {
      KUBECONFIG = "${path.root}/kube_config_cluster.yml"
    }

    command = "helm init --service-account tiller --wait"
  }
}

# Add a basic cinder storageclass
resource "kubernetes_storage_class" "default" {
  metadata {
    name = "default"
  }

  storage_provisioner = "kubernetes.io/cinder"
  reclaim_policy      = "Delete"
}
