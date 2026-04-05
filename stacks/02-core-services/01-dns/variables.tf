variable "dns_vms" {
  type = map(object({
    id          = number
    target_node = string
    cpu         = number
    ram         = number
    disk        = number
    vlan        = number
    ip          = string
  }))
}

variable "nas_ip"         { 
  type = string
  default = "10.0.60.10"
}
variable "ssh_public_key" { type = string }