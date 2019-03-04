/*
 * Security Groups
 */

resource "aws_security_group" "es" {
  vpc_id = "${aws_vpc.main.id}"
  name = "es_${var.es_domain}"
  description = "Allow inbound traffic to ElasticSearch foobar domain"
  ingress = {
    from_port = 9200
	to_port   = 9200
	protocol  = "tcp"
	cidr_blocks = [ "${var.vpc_cidr}" ]
  }
}

