/*
 * ALB Resources
 */

resource "aws_alb_target_group" "eks_tg" {
  name = "eks-${var.eks_cluster_name}"
  vpc_id = "${aws_vpc.main.id}"
  port = 80
  protocol = "HTTP"
  target_type = "instance"
}

resource "aws_alb" "eks_alb" {
  name = "eks-${var.eks_cluster_name}"
  internal = false
  load_balancer_type = "application"
  security_groups = [ "${aws_security_group.eks_alb.id}" ]
  subnets = [ "${aws_subnet.dmz_subnets.*.id}" ]
}

resource "aws_alb_listener" "eks_http" {
  load_balancer_arn = "${aws_alb.eks_alb.arn}"
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
	target_group_arn = "${aws_alb_target_group.eks_tg.arn}"
  }
}

