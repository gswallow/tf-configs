To create a VPC:

TF_VAR_ALLOWED_SSH=0.0.0.0/0 TF_VAR_CIDR_BLOCK=16 terraform apply .

You can also override the TF_VAR_environment and TF_VAR_org environment variables to create your own environment / organization labels..
