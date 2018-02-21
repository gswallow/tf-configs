provider "aws" {}
provider "template" {}

data "aws_region" "current" {
}

data "aws_availability_zones" "available" {}

data "aws_vpc" "selected" {
  tags {
    Environment = "${terraform.workspace}"
  }
}
