variable "proxmox_api_url" { type = string }
variable "proxmox_api_id" { type = string }
variable "proxmox_api_secret" {
    type = string
    sensitive = true
}
variable "ssh_public_key" { type = string }
variable "vault_token" {
    type = string
    sensitive = true
}

variable "k8s_network" {
  type = object({ gateway = string, vlan = number, dns = string })
  default = {
    gateway = "10.0.51.1"
    vlan    = 51
    dns     = "10.0.50.11"
  }
}

variable "k8s_masters" {
  type = map(object({ node = string, vm_id = number, ip = string, cpu = number, ram = number, disk = number }))
  default = {
    "k8s-master-01" = { node = "node1", vm_id = 5111, ip = "10.0.51.11", cpu = 2, ram = 4096, disk = 20 }
    "k8s-master-02" = { node = "node1", vm_id = 5112, ip = "10.0.51.12", cpu = 2, ram = 4096, disk = 20 }
    "k8s-master-03" = { node = "node2", vm_id = 5113, ip = "10.0.51.13", cpu = 2, ram = 4096, disk = 20 }
  }
}

variable "k8s_workers" {
  type = map(object({ node = string, vm_id = number, ip = string, cpu = number, ram = number, disk = number }))
  default = {
    "k8s-worker-01" = { node = "node1", vm_id = 5121, ip = "10.0.51.21", cpu = 4, ram = 8192, disk = 40 }
    "k8s-worker-02" = { node = "node1", vm_id = 5122, ip = "10.0.51.22", cpu = 4, ram = 8192, disk = 40 }
    "k8s-worker-03" = { node = "node1", vm_id = 5123, ip = "10.0.51.23", cpu = 4, ram = 8192, disk = 40 }
    "k8s-worker-04" = { node = "node2", vm_id = 5124, ip = "10.0.51.24", cpu = 4, ram = 8192, disk = 40 }
    "k8s-worker-05" = { node = "node2", vm_id = 5125, ip = "10.0.51.25", cpu = 4, ram = 8192, disk = 40 }
  }
}