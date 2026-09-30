variable "account_id" {
  description = "AWS account authorized for this disposable platform."
  type        = string

  validation {
    condition     = var.account_id == "220263133738"
    error_message = "The platform account must be 220263133738."
  }
}

variable "region" {
  description = "AWS Region for the platform."
  type        = string

  validation {
    condition     = var.region == "eu-north-1"
    error_message = "The platform Region must be eu-north-1."
  }
}

variable "name_prefix" {
  description = "Optional lowercase prefix for disposable resource names."
  type        = string
  default     = ""

  validation {
    condition     = length(var.name_prefix) <= 20 && (var.name_prefix == "" || can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.name_prefix)))
    error_message = "Use an empty prefix or up to 20 lowercase letters, digits, and interior hyphens."
  }
}

variable "vpc_cidr_block" {
  description = "IPv4 CIDR of the disposable VPC."
  type        = string

  validation {
    condition     = var.vpc_cidr_block == "10.80.0.0/16"
    error_message = "The accepted VPC CIDR is 10.80.0.0/16."
  }
}

variable "private_subnets" {
  description = "Private subnet CIDR by explicitly selected availability zone."
  type        = map(string)

  validation {
    condition = var.private_subnets == tomap({
      eu-north-1a = "10.80.0.0/20"
      eu-north-1b = "10.80.16.0/20"
      eu-north-1c = "10.80.32.0/20"
    })
    error_message = "Private subnets must use the accepted three-AZ CIDRs."
  }
}

variable "public_subnets" {
  description = "Public subnet CIDR by explicitly selected availability zone."
  type        = map(string)

  validation {
    condition = var.public_subnets == tomap({
      eu-north-1a = "10.80.48.0/24"
      eu-north-1b = "10.80.49.0/24"
      eu-north-1c = "10.80.50.0/24"
    })
    error_message = "Public subnets must use the accepted three-AZ CIDRs."
  }
}

variable "flow_log_retention" {
  description = "CloudWatch VPC Flow Logs retention in days."
  type        = number

  validation {
    condition     = var.flow_log_retention == 7
    error_message = "VPC Flow Logs must retain seven days."
  }
}

variable "ssh_public_key_path" {
  description = "Path on the owner's laptop to the public SSH key only."
  type        = string

  validation {
    condition     = endswith(var.ssh_public_key_path, ".pub")
    error_message = "Supply a public .pub key file, never the private SSH key."
  }
}

variable "bastion_instance_type" {
  description = "ARM64 bastion instance type."
  type        = string
}
