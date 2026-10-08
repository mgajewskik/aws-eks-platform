provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.tags
  }
}

module "vpc" {
  source = "./modules/vpc"

  name               = local.name
  account_id         = var.account_id
  region             = var.region
  vpc_cidr_block     = var.vpc_cidr_block
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  flow_log_retention = var.flow_log_retention
  tags               = local.tags
}

module "bastion" {
  source = "./modules/bastion"

  name_prefix    = local.name
  vpc_id         = module.vpc.vpc_id
  vpc_cidr       = module.vpc.cidr_block
  subnet_id      = module.vpc.private_subnet_ids[local.bastion_availability_zone]
  ssh_public_key = var.ssh_public_key
  instance_type  = var.bastion_instance_type
  tags           = local.tags

  # Boot only after the NAT route exists: cloud-init and the SSM agent need egress.
  depends_on = [module.vpc]
}
