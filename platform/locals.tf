locals {
  name = var.name_prefix == "" ? "eks-platform" : "${var.name_prefix}-eks-platform"
  tags = { Project = "eks-platform" }

  # The single bastion uses the first availability zone in sorted order.
  bastion_availability_zone = sort(keys(var.private_subnets))[0]
}
