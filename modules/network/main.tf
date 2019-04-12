# Local variable to allow disabling of resources
locals {
  enabled = "${var.enabled ? 1 : 0}"
}

# Network resources
resource "openstack_networking_network_v2" "network" {
  count          = "${local.enabled}"
  name           = "${var.name_prefix}-network"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "subnet" {
  count           = "${local.enabled}"
  name            = "${var.name_prefix}-subnet"
  network_id      = "${openstack_networking_network_v2.network.0.id}"
  cidr            = "${var.subnet_cidr}"
  ip_version      = 4
  dns_nameservers = ["${var.dns_nameservers}"]
  enable_dhcp     = true
}

resource "openstack_networking_router_v2" "router" {
  count               = "${local.enabled}"
  name                = "${var.name_prefix}-router"
  external_network_id = "${var.external_network_id}"
}

resource "openstack_networking_router_interface_v2" "interface" {
  count     = "${local.enabled}"
  router_id = "${openstack_networking_router_v2.router.0.id}"
  subnet_id = "${openstack_networking_subnet_v2.subnet.0.id}"
}
