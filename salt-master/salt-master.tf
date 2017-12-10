resource "aws_launch_configuration" "salt_master" {
  name_prefix                 = "salt_master"
  instance_type               = "t2.micro"
  associate_public_ip_address = "${var.associate_public_ip_address}"
  security_groups             = [ "${data.aws_security_group.selected.id}" ]
  user_data                   = "${file("user-data/master.sh")}"
  key_name                    = "${var.SSH_KEY}"
  image_id                    = "${data.aws_ami.redhat.id}"
  enable_monitoring           = "${var.enable_monitoring}"
}

resource "aws_autoscaling_group" "salt_master" {
  name                 = "salt_master_asg"
  availability_zones   = [ "${data.aws_availability_zones.available.names}" ]
  max_size             = "${var.max_size}"
  min_size             = "${var.min_size}"
  desired_capacity     = "${var.desired_capacity}"
  launch_configuration = "${aws_launch_configuration.salt_master.id}"
  vpc_zone_identifier  = [ "${data.aws_subnet_ids.selected.ids}" ]
  tag {
    key =  "Name"
    value = "salt-master_asg_instance"
    propagate_at_launch = true
  }
  tag {
    key = "Environment"
    value = "${terraform.workspace}"
    propagate_at_launch = true
  }
  tag {
    key = "Purpose"
    value = "salt"
    propagate_at_launch = true
  }
}