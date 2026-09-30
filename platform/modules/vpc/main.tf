resource "aws_vpc" "platform" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.name}-vpc" })
}

resource "aws_default_security_group" "unused" {
  vpc_id  = aws_vpc.platform.id
  ingress = []
  egress  = []

  tags = merge(var.tags, { Name = "${var.name}-unused-default" })
}

resource "aws_internet_gateway" "platform" {
  vpc_id = aws_vpc.platform.id

  tags = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.platform.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${var.name}-public-${each.key}" })
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id                  = aws_vpc.platform.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${var.name}-private-${each.key}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.platform.id

  tags = merge(var.tags, { Name = "${var.name}-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.platform.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Regional NAT has no hosting public subnet or customer-managed EIP.
resource "aws_nat_gateway" "regional" {
  availability_mode = "regional"
  vpc_id            = aws_vpc.platform.id

  tags = merge(var.tags, { Name = "${var.name}-regional-nat" })

  depends_on = [aws_internet_gateway.platform]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.platform.id

  tags = merge(var.tags, { Name = "${var.name}-private" })
}

resource "aws_route" "private_internet" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.regional.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_network_acl" "public" {
  vpc_id = aws_vpc.platform.id

  tags = merge(var.tags, { Name = "${var.name}-public" })
}

resource "aws_network_acl_association" "public" {
  for_each = aws_subnet.public

  network_acl_id = aws_network_acl.public.id
  subnet_id      = each.value.id
}

resource "aws_network_acl" "private" {
  vpc_id = aws_vpc.platform.id

  tags = merge(var.tags, { Name = "${var.name}-private" })
}

resource "aws_network_acl_association" "private" {
  for_each = aws_subnet.private

  network_acl_id = aws_network_acl.private.id
  subnet_id      = each.value.id
}

# NACLs are stateless. VPC traffic supports future internal endpoints and
# control-plane paths; external ephemeral ingress allows internet replies.
# Trivy AWS-0102: accepted coarse intra-VPC allowance; resource SGs own isolation.
#trivy:ignore:AWS-0102
resource "aws_network_acl_rule" "public_ingress_vpc" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr_block
}

resource "aws_network_acl_rule" "public_ingress_http" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "public_ingress_https" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# Trivy AWS-0105: stateless return path spans the client ephemeral range.
#trivy:ignore:AWS-0105
resource "aws_network_acl_rule" "public_ingress_tcp_replies" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 130
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "public_ingress_udp_replies" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 140
  egress         = false
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "public_ingress_icmp_errors" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 150
  egress         = false
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  icmp_type      = 3
  icmp_code      = -1
}

# Trivy AWS-0102: accepted initial outbound internet policy.
#trivy:ignore:AWS-0102
resource "aws_network_acl_rule" "public_egress" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

# Trivy AWS-0102: accepted coarse intra-VPC allowance; resource SGs own isolation.
#trivy:ignore:AWS-0102
resource "aws_network_acl_rule" "private_ingress_vpc" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr_block
}

# Future public NLB targets may preserve client IPs; their security groups
# still constrain the actual targets.
resource "aws_network_acl_rule" "private_ingress_https" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# Trivy AWS-0105: stateless return path spans the client ephemeral range.
#trivy:ignore:AWS-0105
resource "aws_network_acl_rule" "private_ingress_tcp_replies" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "private_ingress_udp_replies" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 130
  egress         = false
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "private_ingress_icmp_errors" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 140
  egress         = false
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  icmp_type      = 3
  icmp_code      = -1
}

# Trivy AWS-0102: accepted initial outbound internet policy through regional NAT.
#trivy:ignore:AWS-0102
resource "aws_network_acl_rule" "private_egress" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

# Trivy AWS-0017: AWS-managed CloudWatch encryption is sufficient for these
# disposable, seven-day traffic metadata logs; no customer KMS key was approved.
#trivy:ignore:AWS-0017
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${var.name}-flow-logs"
  retention_in_days = var.flow_log_retention

  tags = merge(var.tags, { Name = "${var.name}-flow-logs" })
}

data "aws_iam_policy_document" "flow_log_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:ec2:${var.region}:${var.account_id}:vpc-flow-log/*"]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "${var.name}-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_log_assume_role.json

  tags = merge(var.tags, { Name = "${var.name}-flow-logs" })
}

data "aws_iam_policy_document" "flow_log_write" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow_logs.arn}:*"]
  }

  # DescribeLogGroups does not support resource-level permissions. Writes above
  # remain restricted to the Terraform-owned log group.
  statement {
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "flow_log_write" {
  name   = "${var.name}-flow-log-write"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_log_write.json
}

resource "aws_flow_log" "vpc" {
  vpc_id               = aws_vpc.platform.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn         = aws_iam_role.flow_logs.arn

  tags = merge(var.tags, { Name = "${var.name}-vpc-flow-log" })

  depends_on = [aws_iam_role_policy.flow_log_write]
}
