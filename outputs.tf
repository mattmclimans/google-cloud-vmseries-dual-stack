# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "VMSERIES_CLI" {
  value = "ssh admin@${google_compute_instance.vmseries.network_interface.0.access_config.0.nat_ip}"
}

output "VMSERIES_GUI" {
  value = "https://${google_compute_instance.vmseries.network_interface.0.access_config.0.nat_ip}"
}

output "VM_INTERNAL_SSH" {
  value = "gcloud compute ssh paloalto@${google_compute_instance.internal_vm.name}  --zone=${local.zone}"
}

