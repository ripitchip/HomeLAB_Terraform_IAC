resource "proxmox_vm_qemu" "storage_vm" {
  name               = var.name
  vmid               = var.vmid
  target_node        = var.target_node
  memory             = var.ram
  start_at_node_boot = true

  cpu {
    cores = var.cpu
    type  = "host"
  }

  disks {
    ide {
      ide0 {
        cdrom {
          iso = var.iso_image
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          size    = "32G"
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
    tag    = var.vlan
  }

  args = join(" ", [
    for i, disk_id in var.disk_ids : 
      "-drive 'file=/dev/disk/by-id/${disk_id},if=none,id=drive-scsi${i+1},format=raw' -device 'scsi-hd,bus=scsihw0.0,channel=0,scsi-id=${i+1},lun=0,drive=drive-scsi${i+1},id=scsi${i+1},serial=${replace(replace(disk_id, "ata-", ""), "scsi-", "")}'"  ])

  scsihw = "virtio-scsi-pci"
}