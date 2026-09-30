variable "name" {
  description = "Full platform name, including any environment prefix."
  type        = string
}

variable "account_id" {
  description = "Expected AWS account for the flow-log service trust policy."
  type        = string
}

variable "region" {
  description = "AWS Region for the flow-log service trust policy."
  type        = string
}

variable "vpc_cidr_block" {
  description = "IPv4 CIDR of the VPC."
  type        = string
}

variable "private_subnets" {
  description = "Private subnet CIDRs indexed by availability zone."
  type        = map(string)
}

variable "public_subnets" {
  description = "Public subnet CIDRs indexed by availability zone."
  type        = map(string)
}

variable "flow_log_retention" {
  description = "CloudWatch flow log retention in days."
  type        = number
}

variable "tags" {
  description = "Common resource tags, including Project."
  type        = map(string)
}
