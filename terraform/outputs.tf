output "ansible_control_public_ip" {
  description = "Public IP of the bastion/control node - SSH here from your laptop"
  value       = aws_instance.ansible_control.public_ip
}

output "router1_private_ip" {
  description = "Private IP of router1 - use this in the Ansible inventory"
  value       = aws_instance.router1.private_ip
}

output "router2_private_ip" {
  description = "Private IP of router2 - use this in the Ansible inventory"
  value       = aws_instance.router2.private_ip
}

output "ssh_key_file" {
  description = "Path to the generated private key"
  value       = local_file.private_key.filename
}

output "ssh_to_control_node" {
  description = "Ready-to-use SSH command to reach the bastion"
  value       = "ssh -i ${local_file.private_key.filename} ubuntu@${aws_instance.ansible_control.public_ip}"
}
