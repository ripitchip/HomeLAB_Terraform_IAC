variable "name"        { type = string }
variable "vmid"        { type = number }
variable "target_node" { type = string }
variable "iso_image"   { type = string }
variable "cpu"         { type = number }
variable "ram"         { type = number }
variable "vlan"        { type = number }
variable "disk_ids"    { type = list(string) }