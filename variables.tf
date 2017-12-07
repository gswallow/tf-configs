# Variables imported as TF_VAR_*
variable "environment" { default = "dev" }
variable "org" { default = "ivytech" }
variable "CIDR_BLOCK" { default = "16" }

# SSH bastion related variablee
variable "CREATE_BASTION" { default = false }
variable "ALLOWED_SSH" { default = "127.0.0.1/32" }
variable "SSH_KEY" { default = "bootstrap" }
