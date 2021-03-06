variable cluster_prefix {
  description = "Name prefix for the cluster resources"
  default     = "rke"
}

variable "use_bastion" {
  default = true
}

variable ssh_key {
  description = "Local path to SSH key"
}

variable ssh_key_pub {
  description = "Local path to public SSH key"
}

variable ssh_user {
  description = "SSH user name (use the default user for the OS image)"
  default     = "rancher"
}

variable "ssh_agent_auth" {
  description = "Boolean to enable or disable usage of ssh agent auth for RKE"
  default     = true
}

variable custom_network_name {
  description = "Custom network name, which if specified will be used for internal node addresses"
  default     = ""
}

variable external_network_id {
  description = "External network ID"
}

variable floating_ip_pool {
  description = "Name of the floating IP pool (often same as the external network name)"
}

variable image_name {
  description = "Name of an image to boot the nodes from (OS should be Ubuntu 16.04)"
}

variable master_flavor_name {
  description = "Master node flavor name"
}

variable master_count {
  description = "Number of masters to deploy (should be an odd number)"
  default     = 1
}

variable service_flavor_name {
  description = "Service node flavor name"
}

variable service_count {
  description = "Number of service nodes to deploy"
  default     = 2
}

variable edge_flavor_name {
  description = "Edge node flavor name"
}

variable edge_count {
  description = "Number of edge nodes to deploy (this should be at least 1)"
  default     = 1
}

variable ignore_docker_version {
  description = "If true RKE won't check Docker version on images"
  default     = false
}

variable docker_version {
  description = "Docker version (should be RKE-compliant: https://rancher.com/docs/rke/v0.1.x/en/os/#software)"
  default     = "18.09.2"
}

variable kubernetes_version {
  description = "Version of Kubernetes to install in the cluster"
  default     = "v1.13.5-rancher1-2"
}

variable write_kube_config_cluster {
  description = "If true kube_config_cluster.yml will be written locally"
  default     = true
}

variable write_cluster_yaml {
  description = "If true cluster.yml will be written locally"
  default     = true
}

variable master_assign_floating_ip {
  description = "If true a floating IP is assigned to each master node"
  default     = false
}

variable service_assign_floating_ip {
  description = "If true a floating IP is assigned to each service node"
  default     = false
}

variable edge_assign_floating_ip {
  description = "If true a floating IP is assigned to each edge node"
  default     = true
}

variable allowed_ingress_tcp {
  type        = "list"
  description = "Allowed TCP ingress traffic"
  default     = [22, 6443, 80, 443]
}

variable allowed_ingress_udp {
  type        = "list"
  description = "Allowed UDP ingress traffic"
  default     = []
}

variable cloudflare_enable {
  description = "If true it enables Cloudflare dynamic DNS (for this to work CLOUDFLARE_EMAIL and CLOUDFLARE_TOKEN should be set in your environment)"
  default     = false
}

variable cloudflare_domain {
  description = "Cloudflare domain to add the DNS records to (required if enable_cloudflare=true)"
  default     = ""
}

variable cloudflare_email {
  description = "Cloudflare account email (required if enable_cloudflare=true)"
  default     = "null"
}

variable cloudflare_token {
  description = "Cloudflare API key (required if enable_cloudflare=true)"
  default     = "null"
}

variable secondary_volume_size {
  description = "Size in GB of secondary volume for service node instances. Leave 0 to not create"
  default     = 0
}

variable "openstack_username" {
  description = "Openstack admin username for connecting to API for creating volumes, etc"
}

variable "openstack_password" {
  description = "Openstack admin password for connecting to API"
}

variable "openstack_auth_url" {
  description = "Openstack API URL for authentication"
}

variable "openstack_tenant_id" {
  description = "Openstack tenant ID for admin user"
}

variable "openstack_region" {
  description = "Region name for openstack"
  default     = "RegionOne"
}
