variable "name" {
}

variable "common_tags" {}

variable "vpc_id" {
}

#example vpc_cidr "10.0.0.0/16"
variable "vpc_cidr" {
}

# remote_ip_cidr is the ip address of the remote host / user intending to connect over vpn. eg '197.125.62.53/32'
#example "125.254.24.255/32"
variable "remote_ip_cidr" {
}

variable "remote_subnet_cidr" {
}

variable "install_deadline_worker" {}

variable "install_houdini" {}

variable "provision_softnas_volumes" {
  default = []
}

variable "attach_local_mounts_after_start" {
  default = []
}


variable "wakeable" {
  default = true
}

# examples ["subnet-0a7554f56af4d6d0a", "subnet-0257c7f8b1d68b6e4"]
variable "public_subnet_ids" {
  default = []
}

variable "private_subnet_ids" {
  default = []
}

variable "private_subnets_cidr_blocks" {
  default = []
}

variable "aws_key_name" {
}

#contents of the my_key.pem file to connect to the instance.
variable "private_key" {
}

#CentOS Linux 7 x86_64 HVM EBS ENA 1805_01-b7ee8a69-ee97-4a49-9e68-afaee216db2e-ami-77ec9308.4 (ami-d8c21dba)
variable "ami_map" {
  type = map(string)

  default = {
    ap-southeast-2 = "ami-08bd00d7713a39e7d"
  }
}

variable "instance_profile_name" {
}

variable "instance_type" {
}

variable "user" {
  default = "centos"
}

variable "sleep" {
  default = false
}

variable "skip_update" {
  default = true
}

variable "vpn_cidr" {
}

variable "vpn_private_ip" {}

variable "aws_nodes_enabled" {
  default = false
}

variable "region" {
}

variable "aws_private_key_path" {
}

# You may wish to use a custom ami that incorporates your own configuration.  Insert the ami details below if you wish to use this.
variable "use_custom_ami" {
  default = false
}

variable "custom_ami" {
  default = ""
}

variable "bastion_ip" {
}

variable "houdini_license_server_address" {
}

variable "openfirehawkserver" {
}

variable "softnas_private_ip1" {
  default = []
}

variable "softnas_export_path" {
  default = "/naspool2/nasvol2"
}

variable "softnas_mount_path" {
  default = "/mnt/softnas/nasvol2"
}

