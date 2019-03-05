/*
 * Prowler
 */

data "template_file" "policy_lambda" {
  template = "${file("policy/assume-role.tpl")}"
  vars { aws_service = "lambda" }
}

resource "aws_iam_role" "prowler" {
  name = "prowler"
  assume_role_policy = "${data.template_file.policy_lambda.rendered}"
}

resource "aws_iam_policy" "prowler_audit" {
  name = "ProwlerExtraActions"
  policy = "${file("policy/prowler.json")}"
}

resource "aws_iam_role_policy_attachment" "prowler_audit" {
  policy_arn = "${aws_iam_policy.prowler_audit.arn}"
  role = "${aws_iam_role.prowler.name}"
}

resource "aws_iam_role_policy_attachment" "prowler_aws_audit" {
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
  role = "${aws_iam_role.prowler.name}"
}

