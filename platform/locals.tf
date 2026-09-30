locals {
  name = var.name_prefix == "" ? "eks-platform" : "${var.name_prefix}-eks-platform"
  tags = { Project = "eks-platform" }
}
