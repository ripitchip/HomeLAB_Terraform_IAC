variable "proxmox_api_url" { type = string }
variable "proxmox_api_id" { type = string }
variable "proxmox_api_secret" {
    type = string
    sensitive = true
}
variable "ssh_public_key" { type = string }
variable "nas_ip" {
    type = string
    default = "10.0.60.10"
}

variable "vm_config" {
  type = map(any)
  default = {
    name     = "infra-ldap"
    vm_id    = 110
    cpu      = 2
    ram      = 4096
    disk     = 40
    ip       = "10.0.50.10"
    gw       = "10.0.50.1"
    vlan     = 50
    node     = "node1"
    dns_node = "10.0.50.11"
    file_id      = "local:iso/debian-13-generic-amd64.img"
  }
}