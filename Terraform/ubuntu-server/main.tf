terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.71.0"
    }
    keepass = {
      source  = "iSchluff/keepass"
      version = "1.0.1"
    }
  }
}

variable "keepass_password" {
  type      = string
  sensitive = true
  ephemeral = true
}

variable "keepass_database" {
  type     = string
  default = "../../seclab.kdbx"
}

variable "proxmox_host" {
  type        = string
  default     = "proxmox"
  description = "Proxmox node name"
}

variable "hostname" {
  type        = string
  default     = "ubuntu"
  description = "hostname"
}

variable "vm_name" {
  type        = string
  default     = "Ubuntu-Server"
  description = "hostname"
}

variable "template_id" {
  type        = string
  description = "Template ID for clone"
}

provider "keepass" {
  password = var.keepass_password
  database = var.keepass_database
}

data "keepass_entry" "proxmox_api" {
  path = "Passwords/Seclab/proxmox_api"
}

data "keepass_entry" "seclab_user" {
  path = "Passwords/Seclab/seclab_user"
}

provider "proxmox" {
  # Configuration options
  endpoint  = "https://${var.proxmox_host}:8006/api2/json"
  insecure  = true
  api_token = "${data.keepass_entry.proxmox_api.username}=${data.keepass_entry.proxmox_api.password}"
}


resource "proxmox_virtual_environment_vm" "seclab-docker" {
  name      = var.vm_name
  node_name = var.proxmox_host
  on_boot   = true

  clone {
    vm_id = var.template_id
    full  = false
  }

  agent {
    enabled = true
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096
  }

  network_device {
    bridge = "vmbr1"
    model  = "e1000"
  }

  connection {
    type     = "ssh"
    user     = data.keepass_entry.seclab_user.username
    password = data.keepass_entry.seclab_user.password
    host     = self.ipv4_addresses[1][0]
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl hostname ${var.hostname}",
      "sudo netplan apply",
      "ip a s"
    ]
  }


}

output "vm_ip" {
  value       = proxmox_virtual_environment_vm.seclab-docker.ipv4_addresses
  sensitive   = false
  description = "VM IP"
}
