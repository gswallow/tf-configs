resource "aws_route53_zone" "public" {
  name = "${var.zone_name}"
  comment = "${format("Public route53 zone for %s", var.zone_name)}"
  tags { 
    Environment = "${terraform.workspace}"
  }
}

resource "aws_route53_query_log" "public" {
  depends_on = ["aws_cloudwatch_log_resource_policy.public"]
  cloudwatch_log_group_arn = "${aws_cloudwatch_log_group.public.arn}"
  zone_id = "${aws_route53_zone.public.zone_id}"
}

output "public_zone_id" { 
  value = "${aws_route53_zone.public.zone_id}" 
  description = "Route53 hosted zone ID"
}
