variable "proxmox_api_url" { type = string }
variable "proxmox_api_id" { type = string }
variable "proxmox_api_secret" {
  type      = string
  sensitive = true
}
variable "ssh_public_key" { type = string }
variable "nas_ip" { type = string }

variable "reg_config" {
  type = object({
    node     = string
    vm_id    = number
    hostname = string
    fqdn     = string
    ip       = string
    gw       = string
    vlan     = number
    dns      = string
    cpu      = number
    ram      = number
    disk     = number
  })
}

variable "nexus_version" {
  type    = string
  default = "3.91.0-01"
}

variable "nas_path" {
  type    = string
  default = "/mnt/data/infra_storage/reg_data"
}

variable "lldap_search_user" { type = string }
variable "lldap_search_password" {
  type      = string
  sensitive = true
}

variable "ldap_config" {
  type = object({
    url            = string
    base_dn        = string
    group_base_dn  = string
    group_admin_dn = string
  })
}
