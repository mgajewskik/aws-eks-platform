data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  name               = "${var.name_prefix}-bastion"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = merge(var.tags, { Name = "${var.name_prefix}-bastion" })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.name_prefix}-bastion"
  role = aws_iam_role.bastion.name
  tags = merge(var.tags, { Name = "${var.name_prefix}-bastion" })
}

resource "aws_security_group" "bastion" {
  name        = "${var.name_prefix}-bastion"
  description = "Private SSM bastion: outbound HTTPS and VPC administration only"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-bastion" })
}

# SSM uses public regional endpoints through NAT; the rule permits only TCP 443 and no inbound traffic.
#trivy:ignore:AWS-0104
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSM service through regional NAT"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
  tags              = var.tags
}

resource "aws_vpc_security_group_egress_rule" "vpc" {
  security_group_id = aws_security_group.bastion.id
  description       = "Private administration within this VPC"
  ip_protocol       = "-1"
  cidr_ipv4         = var.vpc_cidr
  tags              = var.tags
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2023_arm64.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = false
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
    tags        = var.tags
  }

  user_data = <<-CLOUD_INIT
    #cloud-config
    users:
      - name: ec2-user
        lock_passwd: true
        ssh_authorized_keys:
          - ${jsonencode(trimspace(var.ssh_public_key))}
    ssh_pwauth: false
    disable_root: true
    packages:
      - python3
      - openssh-server
      - amazon-ssm-agent
    write_files:
      - path: /etc/ssh/sshd_config.d/99-bastion.conf
        permissions: '0644'
        content: |
          PasswordAuthentication no
          PermitRootLogin no
    runcmd:
      - [systemctl, enable, --now, sshd]
      - [systemctl, restart, sshd]
      - [systemctl, enable, --now, amazon-ssm-agent]
  CLOUD_INIT

  tags = merge(var.tags, { Name = "${var.name_prefix}-bastion" })
}
