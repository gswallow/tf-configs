provider "aws" {}

data "aws_region" "current" {
 current = true
}

data "aws_availability_zones" "available" {}
