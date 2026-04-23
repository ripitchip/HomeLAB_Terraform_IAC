variable "proxmox_api_url" { type = string }
variable "proxmox_api_id" { type = string }
variable "proxmox_api_secret" {
  type      = string
  sensitive = true
}
variable "ssh_public_key" { type = string }
variable "nas_ip" { type = string }

variable "proxy_config" {
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

variable "nas_path_proxy" {
  type    = string
  default = "/mnt/data/infra_storage/proxy_configs"
}

variable "vault_token" {
  description = "Token d'accès à Vault"
  type        = string
  sensitive   = true # Pour ne pas qu'il s'affiche en clair dans les logs
}