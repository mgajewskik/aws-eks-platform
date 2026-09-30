variable "name_prefix" {
  description = "Full resource prefix, such as eks-platform or dev-eks-platform."
  type        = string
}

variable "vpc_id" {
  description = "VPC containing the private bastion subnet."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC IPv4 CIDR allowed for private administration egress."
  type        = string
}

variable "subnet_id" {
  description = "Private subnet for the bastion."
  type        = string
}

variable "ssh_public_key" {
  description = "Owner's public SSH key. Never pass a private key."
  type        = string

  validation {
    condition     = can(regex("^ssh-(rsa|ed25519) [A-Za-z0-9+/=]+( .*)?$", trimspace(var.ssh_public_key))) && !strcontains(trimspace(var.ssh_public_key), "\n")
    error_message = "ssh_public_key must be one single-line OpenSSH public key."
  }
}

variable "instance_type" {
  description = "ARM64 EC2 instance type; the accepted initial size is t4g.medium."
  type        = string
}

variable "tags" {
  description = "Common non-secret tags, including Project."
  type        = map(string)
}
