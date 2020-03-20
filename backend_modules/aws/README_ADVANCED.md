# Advanced configurations

## mirror

In addition to acting as a bastion host for all other instances, the `mirror` host serves all repos and packages used by other instances.
It works similarly to the one for the libvirt backend, allowing instances in the private subnet to be completely disconnected from the Internet.
The `mirror` host's data volume can be created from a pre-populated snapshot, which allows it to be operational without lengthy channel synchronization.

### Set up mirror machine

When creating mirror machine one have two possibilities:

* Creating using a data disk snapshot:
```hcl
data "aws_ebs_snapshot" "data_disk_snapshot" {
  most_recent = true

  filter {
    name   = "tag:Name"
    values = ["mirror-data-volume-snapshot"]
  }
}

module "mirror" {
  source = "./modules/mirror"

  base_configuration = module.base.configuration
  provider_settings = {
    public_instance = true
  }
  volume_provider_settings = {
    volume_snapshot_id = data.aws_ebs_snapshot.data_disk_snapshot.id
  }
}
```

* Creating with empty data disk (if no snapshot is available):

```hcl
module "mirror" {
  source = "./modules/mirror"

  base_configuration = module.base.configuration

  provider_settings = {
    public_instance = true
  }
}
```
#### Creating data disk snapshot

Requirements:
* Mirror machine in AWS, with the data disk (could be base on pré-existing snapshot, as mentioned before)
* If you use nightly build or DEVEL packages: Access to a full sync mirror (could be local)

Steps:

1. Sync mirror data (this will take some time)

   If you are using released versions or creating a mirror disk from scratch:
   1. `ssh root@<MIRROR_HOST>`
   1. `sudo bash /root/mirror.sh`

   If you are using nightly builds, use DEVEL packages or update an existing mirror:
   1. `scp <YOUR_AWS_KEY> root@<LOCAL_MIRROR_HOST>://root/key.pem`
   2. `ssh root@<MIRROR_HOST>`
   3. `zypper in rsync`
   4. `rsync -av0 --delete -e 'ssh -i key.pem -o "proxycommand ssh -W %h:%p -i key.pem ec2-user@<BASTION_MACHINE_PUBLIC_DNS>"' /srv/mirror/ ec2-user@<MIRROR_PRIVATE_DNS>://srv/mirror/`

2. Create a disk snapshot (this will take some time)
    ```hcl
    data "aws_ebs_volume" "data_disk_id" {
      most_recent = true

      filter {
        name   = "tag:Name"
        values = ["${module.base.configuration["name_prefix"]}mirror-data-volume"]
      }
    }

    resource "aws_ebs_snapshot" "mirror_data_snapshot" {
      volume_id = data.aws_ebs_volume.data_disk_id.id
      timeouts {
        create = "60m"
        delete = "60m"
      }
      tags = {
        Name = "mirror-data-volume-snapshot"
      }
    }
    ```
3. In case you want to delete the mirror instance but keep the snapshot
    1. remove snapshot resource from terraform state: `terraform state rm aws_ebs_snapshot.mirror_data_snapshot`
    2. If you now run `terraform destroy` the snapshot will be preserved.
    However, if one run `terraform apply` again a new snapshot will be created.

#### Force re-creation of existing data disk snapshot

If one keeps the snapshot create resource in is root module, the snapshot will not be re-created unless one forces it by marking the resource as taint.
To remove the older snapshot and create a new one run: `terraform taint aws_ebs_snapshot.mirror_data_snapshot`

## re-use existing infrastructure

One can deploy to existing pre-created infrastructure (VPC, networks, bastion) which should follow the pattern defined for the network. See README.md for more information.  
To use it, a set of properties should be set on sumaform base module.

| Variable name             | Type    | Default value | Description                                                      |
|---------------------------|---------|---------------|------------------------------------------------------------------|
| create_network            | boolean | `true`        | flag indicate if a new infrastructure should be created          |
| public_subnet_id          | string  | `null`        | aws public subnet id                                             |
| private_subnet_id         | string  | `null`        | aws private subnet id                                            |
| public_security_group_id  | string  | `null`        | aws public security group id                                     |
| private_security_group_id | string  | `null`        | aws private security group id                                    |
| bastion_host              | string  | `null`        | bastion machine hostname (to access machines in private network) |          


Example:
```hcl
module "base" {
  source = "./modules/base"
  ...
  provider_settings = {
    create_network            = false
    public_subnet_id          = ...
    private_subnet_id         = ...
    public_security_group_id  = ...
    private_security_group_id = ...
    bastion_host              = ...
  }
}
```   