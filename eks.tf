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

output "kube_cad" {
  value = "${aws_eks_cluster.eks.certificate_authority.0.data}"
}

#--------------------------------------------------------------
# EKS Nodes
#--------------------------------------------------------------
locals {
  eks_node_userdata = <<EOF
#!/bin/bash -xe

CA_CERTIFICATE_DIRECTORY=/etc/kubernetes/pki
CA_CERTIFICATE_FILE_PATH=$CA_CERTIFICATE_DIRECTORY/ca.crt
mkdir -p $CA_CERTIFICATE_DIRECTORY
echo "${aws_eks_cluster.eks.certificate_authority.0.data}" | base64 -d >  $CA_CERTIFICATE_FILE_PATH
INTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
sed -i s,MASTER_ENDPOINT,${aws_eks_cluster.eks.endpoint},g /var/lib/kubelet/kubeconfig
sed -i s,CLUSTER_NAME,${var.eks_cluster_name},g /var/lib/kubelet/kubeconfig
sed -i s,REGION,${var.aws_region},g /etc/systemd/system/kubelet.service
sed -i s,MAX_PODS,20,g /etc/systemd/system/kubelet.service
sed -i s,MASTER_ENDPOINT,${aws_eks_cluster.eks.endpoint},g /etc/systemd/system/kubelet.service
sed -i s,INTERNAL_IP,$INTERNAL_IP,g /etc/systemd/system/kubelet.service
DNS_CLUSTER_IP=10.100.0.10
if [[ $INTERNAL_IP == 10.* ]] ; then DNS_CLUSTER_IP=172.20.0.10; fi
sed -i s,DNS_CLUSTER_IP,$DNS_CLUSTER_IP,g /etc/systemd/system/kubelet.service
sed -i s,CERTIFICATE_AUTHORITY_FILE,$CA_CERTIFICATE_FILE_PATH,g /var/lib/kubelet/kubeconfig
sed -i s,CLIENT_CA_FILE,$CA_CERTIFICATE_FILE_PATH,g  /etc/systemd/system/kubelet.service
systemctl daemon-reload
systemctl restart kubelet
EOF
}

resource "aws_launch_configuration" "eks_node" {
  name_prefix = "eks_${var.eks_cluster_name}_node"
  image_id = "${var.eks_node_ami}"
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
  target_group_arns = [ "${aws_alb_target_group.eks_tg.arn}" ]
  min_size = 1
  max_size = 1
  desired_capacity = 1
  tag {
    key = "Name"
	value = "eks-${var.eks_cluster_name}-node"
	propagate_at_launch = true
  }
}

