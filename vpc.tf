/*
 * Creates network related resources:
 *   - VPC
 *   - DHCP
 *   - Subnets
 *   - Route Tables
 *   - NACLs
 *   - Private NACL Rules
 *   - Hybrid NACL Rules
 *   - DMZ NACL Rules
 */

#--------------------------------------------------------------
# VPC
#--------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block = "${var.vpc_cidr}"
  tags = "${
    map(
      "Name", "vpc-main",
      "kubernetes.io/cluster/${var.eks_cluster_name}", "shared"
	)
  }"
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"
  tags {
    Name = "igw-main"
  }
}

resource "aws_eip" "hybrid_nat" {
  vpc = true
  count = "${length(aws_subnet.hybrid_subnets.*.id)}"
}

resource "aws_nat_gateway" "hybrid" {
  subnet_id = "${element(aws_subnet.hybrid_subnets.*.id, count.index)}"
  allocation_id = "${element(aws_eip.hybrid_nat.*.id, count.index)}"
  count = "${length(var.azs)}"
}

#--------------------------------------------------------------
# DHCP
#--------------------------------------------------------------
resource "aws_vpc_dhcp_options" "dhcp" {
  domain_name = "foobar"
  domain_name_servers = ["AmazonProvidedDNS"]
  tags {
    Name = "dhcp-main"
  }
}

resource "aws_vpc_dhcp_options_association" "dhcp-vpc" {
  vpc_id = "${aws_vpc.main.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.dhcp.id}"
}

#--------------------------------------------------------------
# Subnets
#--------------------------------------------------------------
resource "aws_subnet" "private_subnets" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${cidrsubnet(var.vpc_cidr, 3, count.index)}"
  availability_zone = "${format("%s%s", var.aws_region, var.azs[count.index])}"
  tags {
    Name = "private-${var.azs[count.index]}"
  }
  count = "${length(var.azs)}"
}

resource "aws_subnet" "hybrid_subnets" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${cidrsubnet(var.vpc_cidr, 3, count.index + 2)}"
  availability_zone = "${format("%s%s", var.aws_region, var.azs[count.index])}"
  tags = "${
    map(
      "Name", "hybrid-${var.azs[count.index]}",
      "kubernetes.io/cluster/${var.eks_cluster_name}", "shared"
	)
  }"
  count = "${length(var.azs)}"
}

resource "aws_subnet" "dmz_subnets" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${cidrsubnet(var.vpc_cidr, 3, count.index + 4)}"
  availability_zone = "${format("%s%s", var.aws_region, var.azs[count.index])}"
  tags {
    Name = "dmz-${var.azs[count.index]}"
  }
  count = "${length(var.azs)}"
}

#--------------------------------------------------------------
# Route tables
#--------------------------------------------------------------
resource "aws_route_table" "private_rt" {
  vpc_id = "${aws_vpc.main.id}"
  tags {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "private_rta" {
  subnet_id = "${element(aws_subnet.private_subnets.*.id, count.index)}"
  route_table_id = "${aws_route_table.private_rt.id}"
  count = "${length(var.azs)}"
}

resource "aws_route_table" "hybrid_rt" {
  vpc_id = "${aws_vpc.main.id}"
  tags {
    Name = "hybrid-rt-${var.azs[count.index]}"
  }
  count = "${length(var.azs)}"
}

resource "aws_route_table_association" "hybrid_rta" {
  subnet_id = "${element(aws_subnet.hybrid_subnets.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.hybrid_rt.*.id, count.index)}"
  count = "${length(var.azs)}"
}

resource "aws_route_table" "dmz_rt" {
  vpc_id = "${aws_vpc.main.id}"
  tags {
    Name = "dmz-rt"
  }
}

resource "aws_route_table_association" "dmz_rta" {
  subnet_id = "${element(aws_subnet.dmz_subnets.*.id, count.index)}"
  route_table_id = "${aws_route_table.dmz_rt.id}"
  count = "${length(var.azs)}"
}

resource "aws_route" "hybrid_nat" {
  route_table_id = "${element(aws_route_table.hybrid_rt.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = "${element(aws_nat_gateway.hybrid.*.id, count.index)}"
}

resource "aws_route" "dmz_igw" {
  route_table_id = "${aws_route_table.dmz_rt.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.main.id}"
}

#--------------------------------------------------------------
# NACLs
#--------------------------------------------------------------
resource "aws_network_acl" "private" {
  vpc_id = "${aws_vpc.main.id}"
  subnet_ids = ["${aws_subnet.private_subnets.*.id}"]
  tags = {
    Name = "private-nacl"
  }
}

resource "aws_network_acl" "hybrid" {
  vpc_id = "${aws_vpc.main.id}"
  subnet_ids = ["${aws_subnet.hybrid_subnets.*.id}"]
  tags = {
    Name = "hybrid-nacl"
  }
}

resource "aws_network_acl" "dmz" {
  vpc_id = "${aws_vpc.main.id}"
  subnet_ids = ["${aws_subnet.dmz_subnets.*.id}"]
  tags = {
    Name = "dmz-nacl"
  }
}

#--------------------------------------------------------------
# Private NACL Rules
#--------------------------------------------------------------
resource "aws_network_acl_rule" "private_deny_dmz_ingress" {
  network_acl_id = "${aws_network_acl.private.id}"
  rule_number = "100"
  egress = false
  protocol = "all"
  rule_action = "deny"
  cidr_block = "${cidrsubnet(var.vpc_cidr, 2, 2)}"
}

resource "aws_network_acl_rule" "private_allow_vpc_ingress" {
  network_acl_id = "${aws_network_acl.private.id}"
  rule_number = "500"
  egress = false
  protocol = "all"
  rule_action = "allow"
  cidr_block = "${var.vpc_cidr}"
}

resource "aws_network_acl_rule" "private_deny_dmz_egress" {
  network_acl_id = "${aws_network_acl.private.id}"
  rule_number = "100"
  egress = true
  protocol = "all"
  rule_action = "deny"
  cidr_block = "${cidrsubnet(var.vpc_cidr, 2, 2)}"
}

resource "aws_network_acl_rule" "private_allow_vpc_egress" {
  network_acl_id = "${aws_network_acl.private.id}"
  rule_number = "500"
  egress = true
  protocol = "all"
  rule_action = "allow"
  cidr_block = "${var.vpc_cidr}"
}

#--------------------------------------------------------------
# Hybrid NACL Rules
#--------------------------------------------------------------
resource "aws_network_acl_rule" "hybrid_allow_vpc_ingress" {
  network_acl_id = "${aws_network_acl.hybrid.id}"
  rule_number = "500"
  egress = false
  protocol = "all"
  rule_action = "allow"
  cidr_block = "0.0.0.0/0"
}

resource "aws_network_acl_rule" "hybrid_allow_vpc_egress" {
  network_acl_id = "${aws_network_acl.hybrid.id}"
  rule_number = "500"
  egress = true
  protocol = "all"
  rule_action = "allow"
  cidr_block = "0.0.0.0/0"
}

#--------------------------------------------------------------
# DMZ NACL Rules
#--------------------------------------------------------------
resource "aws_network_acl_rule" "dmz_deny_private_ingress" {
  network_acl_id = "${aws_network_acl.dmz.id}"
  rule_number = "100"
  egress = false
  protocol = "all"
  rule_action = "deny"
  cidr_block = "${cidrsubnet(var.vpc_cidr, 2, 0)}"
}

resource "aws_network_acl_rule" "dmz_allow_all_ingress" {
  network_acl_id = "${aws_network_acl.dmz.id}"
  rule_number = "1000"
  egress = false
  protocol = "all"
  rule_action = "allow"
  cidr_block = "0.0.0.0/0"
}

resource "aws_network_acl_rule" "dmz_deny_private_egress" {
  network_acl_id = "${aws_network_acl.dmz.id}"
  rule_number = "100"
  egress = true
  protocol = "all"
  rule_action = "deny"
  cidr_block = "${cidrsubnet(var.vpc_cidr, 2, 0)}"
}

resource "aws_network_acl_rule" "dmz_allow_all_egress" {
  network_acl_id = "${aws_network_acl.dmz.id}"
  rule_number = "1000"
  egress = true
  protocol = "all"
  rule_action = "allow"
  cidr_block = "0.0.0.0/0"
}

