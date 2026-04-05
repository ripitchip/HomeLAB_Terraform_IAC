module "nas_storage" {
  source      = "../../modules/vm-storage"
  
  name        = var.vm_name
  vmid        = var.vmid
  target_node = "node1" # À adapter selon ton PVE
  vlan        = var.vlan_tag
  cpu         = var.cpu_cores
  ram         = var.memory
  iso_image   = "local:iso/TrueNAS-SCALE-25.10.2.1.iso"
  disk_ids    = var.disk_ids
}

# Déclarations pour le fichier nas.tfvars
variable "vm_name"   { type = string }
variable "vmid"      { type = number }
variable "vlan_tag"  { type = number }
variable "memory"    { type = number }
variable "cpu_cores" { type = number }
variable "disk_ids"  { type = list(string) }