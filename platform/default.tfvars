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
ssh_public_key        = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDEVgjv+bZ0RTmQoJoKSqHzWSNq0+H4b45Qatv9YBjbZVnOxfQLzlbMJfNoAaR9in/WF97OkNasCtp9bzabNgZDs1DVfC68YeMMkFwn81IjIL8Fnlk8qX/KPvW2V3dh6Q8sJgFSNOkVSaSGK+PtikmeSmrY/7/S/kbCE+aaOJHVc4/iyU7xcysoORwghHw6T4hQd7RHe5MtDUpuycVWQBXCN8YM5tkgv1O2DoFBfZgD1/l0hH/akFBRaWHQSA3Rm64jJlqkM8CStSFtbt7O/4JLdOVcpfjF/LCZds7YFkYMt4/+1LsB3OJ/mZB63M83s4RRodfJBKRmbeqtAAXqWqfZT3f8MjPpeai/ocqrH+zKCkd61QfBnSLVd2AE9NMYQFBFTgv5zJ2OHpxSDCl+asNvawCHxw9KQt1hBhxz41SYPloluFzVSOQ1ZiRY+1mQFha8jbLr+qig4uGYxcIHfqzbbfLrcRJcGFJ4YL2TNJcUQUr5OK/rEUeovqqC9mdwUP02jG2l50PjV/jqPJrTXQcttEDB/hg6pYI1olkkwO6IC+Rrgt3R8kksFhy0uMgXIBwZsUfzBvPKMUHt/VSoRl4i9+NEPmh/xx3LwjYvWznAWhkCuutlqNy32IS8DQiroOkpHcd60CmBhccvUHYJITlYr9I6z7H+5+0ndDSIIwqTpw=="
bastion_instance_type = "t4g.medium"
