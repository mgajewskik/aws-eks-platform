output "instance_id" {
  description = "Exact EC2 instance target for Session Manager."
  value       = aws_instance.bastion.id
}

output "private_ip" {
  description = "Bastion private IPv4 address."
  value       = aws_instance.bastion.private_ip
}

output "private_dns" {
  description = "Bastion private DNS name used by the SSH client."
  value       = aws_instance.bastion.private_dns
}

output "ssh_user" {
  description = "Default Amazon Linux SSH user."
  value       = "ec2-user"
}
