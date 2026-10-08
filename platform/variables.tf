variable "account_id" {
  description = "AWS account authorized for this disposable platform."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Use a 12-digit AWS account ID."
  }
}

variable "region" {
  description = "AWS Region for the platform."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", var.region))
    error_message = "Use an AWS Region name such as eu-north-1."
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
    condition     = can(cidrnetmask(var.vpc_cidr_block))
    error_message = "Use an IPv4 CIDR block."
  }
}

variable "private_subnets" {
  description = "Private subnet CIDR by availability zone."
  type        = map(string)

  validation {
    condition     = length(var.private_subnets) == 3 && alltrue([for cidr in values(var.private_subnets) : can(cidrnetmask(cidr))])
    error_message = "Use three availability zones, each with an IPv4 CIDR block."
  }
}

variable "public_subnets" {
  description = "Public subnet CIDR by availability zone."
  type        = map(string)

  validation {
    condition     = keys(var.public_subnets) == keys(var.private_subnets) && alltrue([for cidr in values(var.public_subnets) : can(cidrnetmask(cidr))])
    error_message = "Use the private subnet availability zones, each with an IPv4 CIDR block."
  }
}

variable "flow_log_retention" {
  description = "CloudWatch VPC Flow Logs retention in days."
  type        = number
}

variable "ssh_public_key" {
  description = "OpenSSH public key authorized on the bastion; the private key stays on the owner's laptop."
  type        = string

  validation {
    # The comment field usually holds an email address, which a public repository should not carry.
    condition     = can(regex("^ssh-(rsa|ed25519) [A-Za-z0-9+/=]+$", var.ssh_public_key))
    error_message = "Supply one OpenSSH public key without its comment, never the private key."
  }
}

variable "bastion_instance_type" {
  description = "ARM64 bastion instance type."
  type        = string
}
