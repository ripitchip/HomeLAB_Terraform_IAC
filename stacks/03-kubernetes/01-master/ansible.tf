resource "local_file" "ansible_inventory" {
  content = <<EOT
[masters]
%{ for name, conf in var.k8s_masters ~}
${name} ansible_host=${conf.ip} ansible_user=root
%{ endfor ~}

[workers]
%{ for name, conf in var.k8s_workers ~}
${name} ansible_host=${conf.ip} ansible_user=root
%{ endfor ~}

[k8s:children]
masters
workers
EOT
  filename = "../02-provisioning/inventory/hosts.ini"
}