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
  tags = "${map("kubernetes.io/cluster/${var.eks_cluster_name}", "owned")}"
}

resource "aws_security_group" "eks_node" {
  vpc_id = "${aws_vpc.main.id}"
  name = "eks_${var.eks_cluster_name}_node"
  description = "Security Group for all EKS Nodes"
  egress {
    from_port = 443
	to_port = 443
	protocol = "tcp"
	cidr_blocks = [ "0.0.0.0/0" ]
  }
  tags = "${map("kubernetes.io/cluster/${var.eks_cluster_name}", "owned")}"
}

resource "aws_security_group" "eks_alb" {
  vpc_id = "${aws_vpc.main.id}"
  name = "eks_${var.eks_cluster_name}_alb"
  description = "Security Group for ALB"
  ingress {
    from_port = 80
	to_port = 80
	protocol = "tcp"
	cidr_blocks = [ "0.0.0.0/0" ]
  }
}

resource "aws_security_group_rule" "cluster_egress_node" {
  security_group_id = "${aws_security_group.eks_cluster.id}"
  description = "Allows cluster egress to nodes"
  type = "egress"
  from_port = 1025
  to_port = 65535
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

resource "aws_security_group_rule" "node_ingress_alb" {
  security_group_id = "${aws_security_group.eks_node.id}"
  description = "Allows nodes ingress from alb"
  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  source_security_group_id = "${aws_security_group.eks_alb.id}"
}

resource "aws_security_group_rule" "node_egress_es" {
  security_group_id = "${aws_security_group.eks_node.id}"
  description = "Allows node egress to es"
  type = "egress"
  from_port = 9200
  to_port = 9200
  protocol = "tcp"
  source_security_group_id = "${aws_security_group.es.id}"
}

resource "aws_security_group_rule" "es_ingress_node" {
  security_group_id = "${aws_security_group.es.id}"
  description = "Allows es ingress from nodes"
  type = "ingress"
  from_port = 9200
  to_port = 9200
  protocol = "tcp"
  source_security_group_id = "${aws_security_group.eks_node.id}"
}

resource "aws_security_group_rule" "alb_egress_node" {
  security_group_id = "${aws_security_group.eks_alb.id}"
  description = "Allows alb egress to nodes"
  type = "egress"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  source_security_group_id = "${aws_security_group.eks_node.id}"
}

