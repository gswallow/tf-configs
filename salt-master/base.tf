provider "aws" {}

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

data "aws_ami" "redhat" {
  most_recent = true
  owners = [ "309956199498" ]
  filter {
    name = "name"
    values = [ "RHEL-7.4_*-x86_64-*" ]
  }
  filter {
    name = "virtualization-type"
    values = [ "hvm" ]
  }
  filter {
    name = "root-device-type"
    values = [ "ebs" ]
  }
}
