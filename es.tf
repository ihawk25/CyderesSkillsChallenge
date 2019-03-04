/*
 * ElasticSearch
 */

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "template_file" "policy_es" {
  template = "${file("policy/es.tpl")}"
  vars {
    region = "${data.aws_region.current.name}"
	id     = "${data.aws_caller_identity.current.account_id}"
	domain = "${var.es_domain}"
  }
}

resource "aws_iam_service_linked_role" "es" {
  aws_service_name = "es.amazonaws.com"
}

resource "aws_elasticsearch_domain" "es" {
  domain_name = "${var.es_domain}"
  elasticsearch_version = "6.4"
  cluster_config {
    instance_type = "t2.small.elasticsearch"
    instance_count = 1
  }
  vpc_options {
    subnet_ids = [ "${aws_subnet.private_subnets.*.id[0]}" ]
	security_group_ids = [ "${aws_security_group.es.id}" ]
  }
  ebs_options {
    ebs_enabled = true
	volume_type = "gp2"
	volume_size = 10
  }
  tags {
    Domain = "${var.es_domain}"
  }
  access_policies = "${data.template_file.policy_es.rendered}"
  depends_on = [ "aws_iam_service_linked_role.es" ]
}

