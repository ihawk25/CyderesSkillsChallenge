/*
 * Security Groups
 */

resource "aws_security_group" "es" {
  vpc_id = "${aws_vpc.main.id}"
  name = "es_${var.es_domain}"
  description = "Security Group for ES"
}

resource "aws_security_group" "eks_cluster" {
  vpc_id = "${aws_vpc.main.id}"
  name = "eks_${var.eks_cluster_name}_cluster"
  description = "Security Group for EKS Cluster"
  egress {
    from_port = 0
	to_port = 0
	protocol = "-1"
	cidr_blocks = [ "0.0.0.0/0" ]
  }
}

resource "aws_security_group" "eks_node" {
  vpc_id = "${aws_vpc.main.id}"
  name = "eks_${var.eks_cluster_name}_node"
  description = "Security Group for EKS Nodes"
  egress {
    from_port = 0
	to_port = 0
	protocol = "-1"
	cidr_blocks = [ "0.0.0.0/0" ]
  }
  tags = "${map("kubernetes.io/cluster/${var.eks_cluster_name}", "owned")}"
}

resource "aws_security_group_rule" "node_ingress_self" {
  security_group_id = "${aws_security_group.eks_node.id}"
  description = "Allows nodes to communicate with each other"
  type = "ingress"
  from_port = 0
  to_port = 65535
  protocol = "-1"
  source_security_group_id = "${aws_security_group.eks_node.id}"
}

resource "aws_security_group_rule" "cluster_ingress_node" {
  security_group_id = "${aws_security_group.eks_cluster.id}"
  description = "Allows cluster ingress from nodes"
  type = "ingress"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  source_security_group_id = "${aws_security_group.eks_node.id}"
}

resource "aws_security_group_rule" "node_ingress_cluster" {
  security_group_id = "${aws_security_group.eks_node.id}"
  description = "Allows nodes ingress from cluster"
  type = "ingress"
  from_port = 1025
  to_port = 65535
  protocol = "tcp"
  source_security_group_id = "${aws_security_group.eks_cluster.id}"
}

resource "aws_security_group_rule" "eks_cluster_ingress_tony" {
  security_group_id = "${aws_security_group.eks_cluster.id}"
  description = "Allows Tony access to Cluster API"
  type = "ingress"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  cidr_blocks = ["73.217.253.164/32"]
}

