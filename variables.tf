/*
 * Variables
 */

#--------------------------------------------------------------
# Base
#--------------------------------------------------------------
variable "aws_region" {
  default = "us-west-2"
}

variable "azs" {
  default = ["a","b"]
}

variable "es_domain" {
  default = "foobar"
}

variable "eks_cluster_name" {
  default = "foobar"
}

variable "eks_node_ami" {
  default = "ami-0c28139856aaf9c3b"
}

#--------------------------------------------------------------
# Network
#--------------------------------------------------------------
variable "vpc_cidr" {
  default = "10.0.0.0/22"
}

#--------------------------------------------------------------
# EKS Policies
#--------------------------------------------------------------
variable "eks_cluster_policies" {
  default = [ "AmazonEKSClusterPolicy", "AmazonEKSServicePolicy" ]
}

variable "eks_node_policies" {
  default = [ "AmazonEKSWorkerNodePolicy", "AmazonEKS_CNI_Policy", "AmazonEC2ContainerRegistryReadOnly" ]
}

