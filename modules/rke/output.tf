output kube_config_cluster {
  description = "Kubeconfig file"

  # Workaround: https://github.com/rancher/rke/issues/705
  value     = "${replace(coalesce("", join("", rke_cluster.cluster_no_bastion.*.kube_config_yaml), join("", rke_cluster.cluster.*.kube_config_yaml)), local.api_access_regex, local.api_access)}"
  sensitive = true
}

output cluster_yml {
  description = "RKE cluster.yml file"
  value       = "${coalesce("", join("", rke_cluster.cluster_no_bastion.*.rke_cluster_yaml), join("", rke_cluster.cluster.*.rke_cluster_yaml))}"
}
