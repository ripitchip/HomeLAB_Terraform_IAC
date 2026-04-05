variable "proxmox_api_url"    { type = string }
# variable "proxmox_api_id"     { type = string }
# variable "proxmox_api_secret" {
#     type = string
#     sensitive = true 
# }
variable "proxmox_api_user"     { type = string }
variable "proxmox_api_password" {
    type = string
    sensitive = true
}