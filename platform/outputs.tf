output "connection" {
  description = "Identity and private bastion details consumed by local connection tasks."
  value = {
    account_id  = var.account_id
    region      = var.region
    instance_id = module.bastion.instance_id
    vpc_cidr    = module.vpc.cidr_block
    ssh_user    = module.bastion.ssh_user
    private_ip  = module.bastion.private_ip
    private_dns = module.bastion.private_dns
  }
}
