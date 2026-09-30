output "vpc_id" {
  description = "Disposable VPC ID."
  value       = aws_vpc.platform.id
}

output "cidr_block" {
  description = "Disposable VPC CIDR."
  value       = aws_vpc.platform.cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs indexed by availability zone."
  value       = { for az, subnet in aws_subnet.private : az => subnet.id }
}

output "public_subnet_ids" {
  description = "Public subnet IDs indexed by availability zone."
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
}
