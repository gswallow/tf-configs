# Variables imported as TF_VAR_*
variable "environment" { default = "dev" }
variable "org" { default = "ivytech" }
variable "CIDR_BLOCK" { default = "16" }

# SSH bastion related variablee
variable "CREATE_BASTION" { default = false }
variable "ALLOWED_SSH" { default = "127.0.0.1/32" }
variable "SSH_KEY" { default = "bootstrap" }

####################################################

resource "aws_vpc" "main" {
  cidr_block = "172.${var.CIDR_BLOCK}.0.0/16"
  enable_dns_support = "true"
  tags {
    Environment = "${var.environment}"
    Name = "${format("%s-%s-172.%s.0.0-16", var.org, var.environment, var.CIDR_BLOCK)}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"
  tags {
    Environment = "${var.environment}"
  }
}

# Public subnets.  Easy Peasy.
resource "aws_subnet" "public" {
  count = "${length(data.aws_availability_zones.available.names)}"
  vpc_id = "${aws_vpc.main.id}"
  availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"
  cidr_block = "172.${var.CIDR_BLOCK}.${count.index * 4}.0/22"
  tags {
    Environment = "${var.environment}"
    Type = "public"
    Name = "${format("%s-public", element(data.aws_availability_zones.available.names, count.index))}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.main.id}"
  }
  tags {
    Environment = "${var.environment}"
    Type = "public"
  }
}

resource "aws_route_table_association" "public" {
  count = "${length(data.aws_availability_zones.available.names)}"
  subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

# NATted subnets require NAT gateways and route tables.
resource "aws_eip" "nat" {
  count = "${length(data.aws_availability_zones.available.names)}"
}

resource "aws_nat_gateway" "gw" {
  count = "${length(data.aws_availability_zones.available.names)}"
  allocation_id = "${element(aws_eip.nat.*.id, count.index)}"
  subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
  tags {
    Environment = "${var.environment}"
  }
}

resource "aws_subnet" "nat" {
  count = "${length(data.aws_availability_zones.available.names)}"
  vpc_id = "${aws_vpc.main.id}"
  availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"
  cidr_block = "172.${var.CIDR_BLOCK}.${count.index * 4 + 64}.0/22"
  tags {
    Environment = "${var.environment}"
    Type = "nat"
    Name = "${format("%s-NAT", element(data.aws_availability_zones.available.names, count.index))}"
  }
}

resource "aws_route_table" "nat" {
  count = "${length(data.aws_availability_zones.available.names)}"
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${element(aws_nat_gateway.gw.*.id, count.index)}"
  }
  tags {
    Environment = "${var.environment}"
    Type = "public"
  }
}

resource "aws_route_table_association" "nat" {
  count = "${length(data.aws_availability_zones.available.names)}"
  subnet_id = "${element(aws_subnet.nat.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.nat.*.id, count.index)}"
}

# Private (no internet) subnets
resource "aws_subnet" "private" {
  count = "${length(data.aws_availability_zones.available.names)}"
  vpc_id = "${aws_vpc.main.id}"
  availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"
  cidr_block = "172.${var.CIDR_BLOCK}.${count.index * 4 + 192}.0/22"
  tags {
    Environment = "${var.environment}"
    Type = "private"
    Name = "${format("%s-private", element(data.aws_availability_zones.available.names, count.index))}"
  }
}

# Three basic security groups
resource "aws_security_group" "web" {
  name = "default_web"
  description = "Allow HTTP and HTTPS from the public"
  vpc_id = "${aws_vpc.main.id}"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "TCP"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    from_port = 443
    to_port = 443
    protocol = "TCP"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    from_port = 0 
    to_port = 0 
    protocol = "-1" 
    self = true
  }
  tags {
    Name = "default_web_sg"
  }
} 

resource "aws_security_group" "ssh" {
  name = "default_ssh"
  description = "Allow SSH from specified CIDR blocks"
  vpc_id = "${aws_vpc.main.id}"
  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = [ "${var.ALLOWED_SSH}" ]
  }
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    self = true
  }
  tags {
    Name = "default_ssh_sg"
  }
}

resource "aws_security_group" "private" {
  name = "private"
  description = "Private subnet accessible by SSH bastions"
  vpc_id = "${aws_vpc.main.id}"
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    security_groups = [ "${aws_security_group.ssh.id}" ]
    self = true
  }
  tags {
    Name = "private_sg"
  }
}

# SSH bastion, if $TF_VAR_CREATE_BASTION is true

resource "aws_instance" "bastion" {
  count = "${var.CREATE_BASTION == "true" ? 1 : 0 }"
  ami = "${data.aws_ami.amazon.id}"
  instance_type = "t2.micro"
  key_name = "${var.SSH_KEY}"
  security_groups = [ "${aws_security_group.ssh.id}" ]
  subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
  associate_public_ip_address = true
  tags {
    Name = "bastion_ec2_instance"
    Environment = "${var.environment}"
  }
}
