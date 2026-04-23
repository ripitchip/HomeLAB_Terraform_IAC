variable "proxmox_api_url"    { type = string }
variable "proxmox_api_id"     { type = string }
variable "proxmox_api_secret" { 
  type = string 
  sensitive = true
}
variable "ssh_public_key"     { type = string }
variable "nas_ip"             { type = string }
variable "nexus_ip"           { type = string } # Doit être 10.0.50.15

variable "vault_config" {
  type = object({
    node     = string
    vm_id    = number
    hostname = string
    ip       = string
    gw       = string
    vlan     = number
    dns      = string
    cpu      = number
    ram      = number
    disk     = number
  })
}

variable "nas_path_vault" {
  type    = string
  default = "/mnt/data/infra_storage/hashicorp_vault"
}