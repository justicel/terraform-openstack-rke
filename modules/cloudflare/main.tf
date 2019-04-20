############ Variables
variable cloudflare_enable {
  description = "If true it enables Cloudflare dynamic DNS"
}

variable cloudflare_domain {
  description = "Cloudflare domain to add the DNS records to (required if enable_cloudflare=true)"
  default     = ""
}

variable dns_value_list {
  type        = "list"
  description = "List of DNS values (an LB record will be created for each of these)"
}

variable dns_record_count {
  description = "Count of Edge nodes that are created to use for resource counts to avoid terraform issues"
}

variable "prefix" {
  description = "Prefix to use when creating cloudflare load-balancer"
  default     = "default"
}

variable "hostnames" {
  description = "Prefix of node names to apply to pool"
}

variable "expected_body" {
  description = "Expected content of cloudflare LB monitor"
  default     = ""
}

variable "expected_codes" {
  description = "Expected return codes for cloudflare LB monitor"
  default     = "2xx"
}

variable "method" {
  description = "Request type for cloudflare LB monitor"
  default     = "GET"
}

variable "timeout" {
  description = "Timeout for cloudflare LB monitor checks"
  default     = 10
}

variable "path" {
  description = "Path for cloudflare LB monitor checks"
  default     = "/healthz"
}

variable "interval" {
  description = "Interval for cloudflare LB monitor checks"
  default     = 60
}

variable "retries" {
  description = "Retry cound for cloudflare LB monitor checks"
  default     = 5
}

variable "description" {
  description = "Description for cloudflare monitor"
  default     = "Ingress load-balancer"
}

variable "notification_email" {
  description = "E-mail address to send LB monitored issues"
  default     = "hosting@acenda.com"
}

variable "enable_proxy" {
  description = "Enable proxying on cloudflare"
  default     = true
}

############ Main Body
data "null_data_source" "dns_value_list" {
  count = "${length(var.dns_record_count)}"

  inputs = {
    name    = "${var.prefix}-${var.hostnames}-${count.index}"
    address = "${var.dns_value_list[count.index]}"
    enabled = true
  }
}

locals {
  enable = "${var.cloudflare_enable ? 1 : 0}"
}

resource "cloudflare_load_balancer_monitor" "cloudflare" {
  count          = "${local.enable}"
  expected_body  = "${var.expected_body}"
  expected_codes = "${var.expected_codes}"
  method         = "${var.method}"
  timeout        = "${var.timeout}"
  path           = "${var.path}"
  interval       = "${var.interval}"
  retries        = "${var.retries}"
  description    = "${var.description} Monitor - ${var.prefix}"
}

resource "cloudflare_load_balancer_pool" "cloudflare" {
  count = "${local.enable}"
  name  = "${var.prefix}-lb-pool"

  origins = ["${data.null_data_source.dns_value_list.*.outputs}"]

  description        = "${var.description} Pool - ${var.prefix}"
  enabled            = true
  minimum_origins    = 1
  notification_email = "${var.notification_email}"
  monitor            = "${cloudflare_load_balancer_monitor.cloudflare.0.id}"
}

resource "cloudflare_load_balancer" "cloudflare" {
  count            = "${local.enable}"
  zone             = "${var.cloudflare_domain}"
  name             = "${var.prefix}-lb.${var.cloudflare_domain}"
  fallback_pool_id = "${cloudflare_load_balancer_pool.cloudflare.0.id}"
  default_pool_ids = ["${cloudflare_load_balancer_pool.cloudflare.0.id}"]
  description      = "${var.description} Load Balancer - ${var.prefix}/${var.cloudflare_domain}"
  proxied          = "${var.enable_proxy}"
}
