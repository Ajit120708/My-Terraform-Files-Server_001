output "bastion_public_ip" {
  value = aws_instance.bastion_host.public_ip
}

output "ssh_command" {
  value = "ssh ubuntu@${aws_instance.bastion_host.public_ip}"
}
