provider "aws" {}
provider "template" {}
provider "random" {}

data "aws_region" "current" {
 current = true
}

data "aws_availability_zones" "available" {}

data "aws_vpc" "selected" {
  tags {
    Environment = "${terraform.workspace}"
  }
}

data "aws_subnet_ids" "selected" {
  vpc_id = "${data.aws_vpc.selected.id}"
  tags {
    Type = "nat"
  }
}

data "aws_security_group" "selected" {
  vpc_id = "${data.aws_vpc.selected.id}"
  name = "private"
}

data "aws_route53_zone" "internal" {
  vpc_id = "${data.aws_vpc.selected.id}"
  name = "${format("%s.%s", terraform.workspace, var.ORG)}"
  tags {
    Environment = "${terraform.workspace}"
  }
}

resource "random_string" "password" {
  length = 16
  special = true
}
