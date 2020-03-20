locals {
  availability_zone = lookup(var.provider_settings, "availability_zone", null)
  region            = lookup(var.provider_settings, "region", null)
  ssh_allowed_ips   = lookup(var.provider_settings, "ssh_allowed_ips", [])
  name_prefix       = var.name_prefix

  key_name = lookup(var.provider_settings, "key_name", null)
  key_file = lookup(var.provider_settings, "key_file", null)
  ssh_user = lookup(var.provider_settings, "ssh_user", "ec2-user")
}

data "aws_ami" "opensuse150" {
  most_recent      = true
  name_regex       = "^openSUSE-Leap-15-v"
  owners           = ["679593333241"]

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_ami" "opensuse151" {
  most_recent      = true
  name_regex       = "^openSUSE-Leap-15-1-v"
  owners           = ["679593333241"]

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

module "network" {
  source = "../network"

  availability_zone = local.availability_zone
  region            = local.region
  ssh_allowed_ips   = local.ssh_allowed_ips
  name_prefix       = local.name_prefix
}

locals {
  configuration_output = merge({
    cc_username          = var.cc_username
    cc_password          = var.cc_password
    timezone             = var.timezone
    ssh_key_path         = var.ssh_key_path
    mirror               = var.mirror
    use_mirror_images    = var.use_mirror_images
    use_avahi            = var.use_avahi
    domain               = var.domain
    name_prefix          = var.name_prefix
    use_shared_resources = var.use_shared_resources
    testsuite            = var.testsuite

    additional_network = lookup(var.provider_settings, "additional_network", null)

    region            = local.region
    availability_zone = local.availability_zone

    key_name = local.key_name
    key_file = local.key_file
    ssh_user = local.ssh_user
    images_ami = {
      opensuse151 = data.aws_ami.opensuse151.image_id,
      opensuse150 = data.aws_ami.opensuse150.image_id,
      }
    },
  module.network.configuration)
}

module "bastion" {
  source             = "../host"
  base_configuration = local.configuration_output
  image              = "opensuse151"
  name               = "bastion"
  provision          = false
  cloud_init         = false
  provider_settings = {
    instance_type   = "t2.micro"
    public_instance = true
  }
}

output "configuration" {
  value = merge(local.configuration_output, {
    bastion_host = length(module.bastion.configuration.public_names) > 0 ? module.bastion.configuration.public_names[0] : null
  })
}
