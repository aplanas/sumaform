 # AWS-specific configuration

## Overview

Base Module will create:
 - a VPC
 - two subnets
   - one private, that can only access other hosts in the VPC
   - one public, that can also access the Internet and accepts connections from an IP whitelist
 - security groups, routing tables, Internet gateways, NAT gateway as appropriate
 - one `bastion` host is also created in the public network

This architecture is based on [AWS VPC with Public and Private Subnets](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Scenario2.html).

A mirror is not mandatory but can be created to speed up machine provisioning (see README_ADVANCED.md).
If un-release version or SLES AMI are in use a mirror with manual sync is mandatory.

## Prerequisites

You will need:
 - an AWS account, specifically an Access Key ID and a Secret Access Key
 - [an SSH key pair](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#having-ec2-create-your-key-pair) valid for that account
 - the name of the region and availability zone you want to use.

## Select AWS backend to be used

Create a symbolic link to the `aws` backend module directory inside the `modules` directory: `ln -sfn ../backend_modules/aws modules/backend`

## AWS backend specific variables

Most modules have configuration settings specific to the AWS backend, those are set via the `provider_settings` map variable. They are all described below.

### Base Module
Available provider settings for the base module:

| Variable name      | Type   | Default value | Description                                                              |
|--------------------|--------|---------------|--------------------------------------------------------------------------|
| region             | string | `null`        | AWS region where infrastructure will be created                          |
| availability_zone  | string | `null`        | AWS availability zone inside region                                      |
| ssh_allowed_ips    | array  | `[]`          | Array of IP's to white list for ssh connection                           |
| key_name           | string | `null`        | ssh key name in AWS                                                      |
| key_file           | string | `null`        | ssh key file                                                             |
| ssh_user           | string | `ec2-user`    | ssh user                                                                 |
| bastion_host       | string | `null`        | bastian host use to connect machines in private network                  |
| additional_network | string | `null`        | A network mask for PXE tests                                             |

An example follows:
```hcl-terraform
...
provider_settings = {
    region            = "eu-west-3"
    availability_zone = "eu-west-3a"
    ssh_allowed_ips   = ["1.2.3.4"]
    key_name = "my-aws-key"
    key_file = "/path/to/key.pem"
}
...
```

### Host modules

Following settings apply to all modules that create one or more hosts of the same kind, such as `suse_manager`, `suse_manager_proxy`, `client`, `grafana`, `minion`, `mirror`, `sshminion`, `pxe_boot` and `virthost`:

| Variable name   | Type     | Default value                                                    | Description                                                         |
|-----------------|----------|------------------------------------------------------------------|---------------------------------------------------------------------|
| key_name        | string   | [from base Module](base-module)                                  | ssh key name in AWS                                                 |
| key_file        | string   | [from base Module](base-module)                                  | ssh key file                                                        |
| ssh_user        | string   | [from base Module](base-module)                                  | ssh user                                                            |
| bastion_host    | string   | [from base Module](base-module)                                  | bastian host use to connect machines in private network             |
| public_instance | boolean  | `false`                                                          | boolean to set host to private or public network                    |
| volume_size     | number   | `50`                                                             | main volume size in GB                                              |
| instance_type   | string   | `t2.micro`([apart from specific roles](Default-values-by-role))  | [AWS instance type](https://aws.amazon.com/pt/ec2/instance-types/)  |
| ami             | string   | value get from base module using the image field                 | AWS ami id that should be used. Overwrite image field               |

An example follows:
```hcl
...
  provider_settings = {
    public_instance = true
    instance_type   = "t2.small"
  }
...
```

`server`, `proxy` and `mirror` modules have configuration settings specific for extra data volumes, those are set via the `volume_provider_settings` map variable. They are described below.

 * `volume_snapshot_id = <String>` data volume snapshot id to be used as base for the new disk (default value `null`)
 * `type = <String>` Disk type that should be used (default value `sc1`). One of: "standard", "gp2", "io1", "sc1" or "st1".

 An example follows:
 ``` hcl
volume_provider_settings = {
  volume_snapshot_id = "my-data-snapshot"
}
```

#### Default provider settings by role

Some roles such as `server` or `mirror` have specific defaults that override those in the table above. Those are:

| Role         | Default values                |
|--------------|-------------------------------|
| server       | `{instance_type="t2.medium"}` |
| mirror       | `{instance_type="t2.micro"}`  |
| controller   | `{instance_type="t2.medium"}` |
| grafana      | `{instance_type="t2.medium"}` |
| virthost     | `{instance_type="t2.small"}`  |
| pts_minion   | `{instance_type="t2.medium"}` |

## Supported images

### Server and Proxy:

| Product          | Image         | Supported | 
| ---------------- | ------------- | --------- |
| uyuni-released   | Opensuse 15.1 | yes       |
| uyuni-master     | Opensuse 15.1 | yes       |
| head             | sles15sp2     | No        |
| 4.0-nightly      | sles15sp1     | No        |

### Client and minion

| Image         | Supported |
| ------------- | --------- |
| Opensuse 15.1 | yes       |
| Opensuse 15   | yes       |
| ~sles15sp2~   | No        |
| sles15sp1     | No |
| sles15        | yes, with mirror (see README_ADVANCED.md) |
| sles12sp4     | No |
| sles12sp3     | No |
| sles12sp2     | No |
| sles12sp1     | No |
| sles12        | No |
| sles11sp4     | No |
| centos6       | No |
| centos7       | No |
| centos8       | No |
| ubuntu1804    | No |
| ubuntu1604    | No |

## Accessing instances

`bastion` is accessible through SSH at the public name noted in outputs.

```
$ terraform apply
...
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

bastion_host = ec2-XXX-XXX-XXX-XXX.compute-1.amazonaws.com

$ ssh -i key.pem root@ec2-XXX-XXX-XXX-XXX.compute-1.amazonaws.com
ip-YYY-YYY-YYY-YYY:~ #
```

Other hosts are accessible via SSH from the `bastion` itself.

This project provides a utility script, `configure_aws_tunnels.rb`, which will add `Host` definitions in your SSH config file so that you don't have to input tunneling flags manually.

```
$ terraform apply
...
$ ./configure_aws_tunnels.rb
$ ssh server
ip-YYY-YYY-YYY-YYY:~ #
```
