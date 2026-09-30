account_id     = "220263133738"
region         = "eu-north-1"
name_prefix    = ""
vpc_cidr_block = "10.80.0.0/16"
private_subnets = {
  eu-north-1a = "10.80.0.0/20"
  eu-north-1b = "10.80.16.0/20"
  eu-north-1c = "10.80.32.0/20"
}
public_subnets = {
  eu-north-1a = "10.80.48.0/24"
  eu-north-1b = "10.80.49.0/24"
  eu-north-1c = "10.80.50.0/24"
}
flow_log_retention    = 7
ssh_public_key_path   = "~/.ssh/aws-eks-platform.pub"
bastion_instance_type = "t4g.medium"
