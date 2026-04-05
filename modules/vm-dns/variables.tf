variable "target_node" {
  type        = string
  description = "Le node Proxmox cible (ex: node1)"
}

variable "ssh_public_key" {
  type        = string
  description = "Ta clé SSH publique pour l'accès Cloud-Init"
}

variable "vmid" {
  type        = number
  default     = 5011
}

variable "vm_name" {
  type        = string
  default     = "infra-dns"
}

variable "nas_ip" {
  type        = string
  default     = "10.0.60.10"
}