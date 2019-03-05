/*
 * EKS
 */

data "template_file" "policy_ar_eks" {
  template = "${file("policy/assume-role.tpl")}"
  vars { aws_service = "eks" }
}

data "template_file" "policy_ar_ec2" {
  template = "${file("policy/assume-role.tpl")}"
  vars { aws_service = "ec2" }
}

data "aws_ami" "eks_node" {
  filter {
    name = "name"
    values = [ "amazon-eks-node-${aws_eks_cluster.eks.version}-v*" ]
  }
  most_recent = true
  owners = [ "602401143452" ]
}

#--------------------------------------------------------------
# IAM Roles
#--------------------------------------------------------------
resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster"
  assume_role_policy = "${data.template_file.policy_ar_eks.rendered}"
}

resource "aws_iam_role" "eks_node" {
  name = "eks-node"
  assume_role_policy = "${data.template_file.policy_ar_ec2.rendered}"
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  policy_arn = "arn:aws:iam::aws:policy/${var.eks_cluster_policies[count.index]}"
  role = "${aws_iam_role.eks_cluster.name}"
  count = "${length(var.eks_cluster_policies)}"
}

resource "aws_iam_role_policy_attachment" "eks_node" {
  policy_arn = "arn:aws:iam::aws:policy/${var.eks_node_policies[count.index]}"
  role = "${aws_iam_role.eks_node.name}"
  count = "${length(var.eks_node_policies)}"
}

resource "aws_iam_instance_profile" "eks_node" {
  name = "eks-node"
  role = "${aws_iam_role.eks_node.name}"
}

#--------------------------------------------------------------
# EKS Cluster
#--------------------------------------------------------------
resource "aws_eks_cluster" "eks" {
  name = "${var.eks_cluster_name}"
  role_arn = "${aws_iam_role.eks_cluster.arn}"
  vpc_config {
    subnet_ids = [ "${aws_subnet.hybrid_subnets.*.id}" ]
	security_group_ids = [ "${aws_security_group.eks_cluster.id}" ]
  }
}

output "endpoint" {
  value = "${aws_eks_cluster.eks.endpoint}"
}

output "certificate_authority_data" {
  value = "${aws_eks_cluster.eks.certificate_authority.0.data}"
}

#--------------------------------------------------------------
# EKS Nodes
#--------------------------------------------------------------
locals {
  eks_node_userdata = <<EOF
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.eks.endpoint}' --b64-cluster-ca '${aws_eks_cluster.eks.certificate_authority.0.data}' '${var.eks_cluster_name}'
EOF
  config_map_aws_auth = <<EOF


apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.eks_node.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF
  kubeconfig = <<EOF


apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.eks.endpoint}
    certificate-authority-data: ${aws_eks_cluster.eks.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${var.eks_cluster_name}"
EOF
}

resource "aws_launch_configuration" "eks_node" {
  name_prefix = "eks_${var.eks_cluster_name}_node"
  image_id = "${data.aws_ami.eks_node.id}"
  instance_type = "t2.small"
  iam_instance_profile = "${aws_iam_instance_profile.eks_node.name}"
  security_groups = [ "${aws_security_group.eks_node.id}" ]
  user_data_base64 = "${base64encode(local.eks_node_userdata)}"

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "eks_node" {
  name = "eks_${var.eks_cluster_name}_node"
  vpc_zone_identifier = [ "${aws_subnet.hybrid_subnets.*.id}" ]
  launch_configuration = "${aws_launch_configuration.eks_node.id}"
  min_size = 1
  max_size = 1
  desired_capacity = 1
  tag {
    key = "Name"
    value = "eks-${var.eks_cluster_name}-node"
    propagate_at_launch = true
  }
  tag {
    key = "kubernetes.io/cluster/${var.eks_cluster_name}"
    value = "owned"
    propagate_at_launch = true
  }
}

output "config_map_aws_auth" {
  value = "${local.config_map_aws_auth}"
}

output "kubeconfig" {
  value = "${local.kubeconfig}"
}

