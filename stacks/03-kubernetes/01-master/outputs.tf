output "k8s_masters_ips" {
  description = "Adresses IP des nœuds Masters"
  value       = { for k, v in var.k8s_masters : k => v.ip }
}

output "k8s_workers_ips" {
  description = "Adresses IP des nœuds Workers"
  value       = { for k, v in var.k8s_workers : k => v.ip }
}

output "vm_ids" {
  description = "IDs des VMs créées sur Proxmox"
  value       = { for k, v in proxmox_virtual_environment_vm.k8s_vms : k => v.vm_id }
}