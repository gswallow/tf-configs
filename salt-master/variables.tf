# Variables imported as TF_VAR_*
variable "SSH_KEY" { default = "bootstrap" }

# Defaults
variable "max_size" { default = "1" }
variable "min_size" { default = "0" }
variable "desired_capacity" { default = "1" } 
variable "associate_public_ip_address" { default = "false" }
variable "enable_monitoring" { default = "true" }
