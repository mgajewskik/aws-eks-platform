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
  subnet_id      = module.vpc.private_subnet_ids["eu-north-1a"]
  ssh_public_key = file(pathexpand(var.ssh_public_key_path))
  instance_type  = var.bastion_instance_type
  tags           = local.tags

  depends_on = [module.vpc]
}
