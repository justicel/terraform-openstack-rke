output "node_mappings" {
  description = "RKE node mappings"
  value       = ["${data.rke_node_parameter.node_mappings.*.json}"]
}

output "private_ip_list" {
  description = "List of private IP addresses"

  value = ["${coalescelist(
    openstack_compute_instance_v2.instance_secondary_volume.*.network.0.fixed_ip_v4,
    openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4
  )}"]
}

output "public_ip_list" {
  description = "List of floating IP addresses"
  value       = ["${openstack_compute_floatingip_v2.floating_ip.*.address}"]
}

output "prepare_nodes_id_list" {
  description = "Prepare nodes provisioner resource ID list"
  value       = ["${null_resource.prepare_nodes.*.id}"]
}

output "associate_floating_ip_id_list" {
  description = "Associate floating IP resource ID list"
  value       = ["${openstack_compute_floatingip_associate_v2.associate_floating_ip.*.id}"]
}
