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
variable "lldap_search_user" {
  type        = string
  description = "L'UID de l'utilisateur utilisé par Harbor pour interroger le LDAP (ex: thomas ou harbor_svc)"
}

variable "lldap_search_password" {
  type      = string
  sensitive = true
}

variable "harbor_admin_password" {
  type      = string
  sensitive = true
}

# On simplifie l'objet ldap_config (on enlève search_dn qui est construit dynamiquement)
variable "ldap_config" {
  type = object({
    url            = string
    base_dn        = string
    group_base_dn  = string
    group_admin_dn = string
  })
}
