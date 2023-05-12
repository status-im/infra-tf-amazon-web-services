# Description

This is a helper module used by Status internal repos like: [infra-hq](https://github.com/status-im/infra-hq), [infra-misc](https://github.com/status-im/infra-misc), [infra-eth-cluster](https://github.com/status-im/infra-eth-cluster), or [infra-swarm](https://github.com/status-im/infra-swarm).

# Usage

Simply import the modue using the `source` directive:
```hcl
module "amazon-web-services" {
  source = "github.com/status-im/infra-tf-amazon-web-services"
}
```

[More details.](https://www.terraform.io/docs/modules/sources.html#github)

# Variables

* __Scaling__
  * `host_count` - Number of hosts to start in this region.
  * `image_name` - OS image used to create host. (default: `ubuntu-bionic-18.04-amd64`)
  * `image_owner` - Idenitifier of AWS AMI image owner. (default: `099720109477`)
  * `type` - Type of host to create. (default: `t2.micro`)
  * `zone` - Availability Zone in which the instance will be created. (default: `eu-central-1a`)
  * `root_vol_size` - Size in GiB of system rot volume. (default: 10 GB)
  * `data_vol_size` - Size in GiB of an extra volume to attach to the instance. (default: `0`)
  * `data_vol_type` - Type of the data volume: `standard`, `gp2`, `io1`, `sc1`, `st1`. (default: `standard`)
  * `data_vol_iops` - Amount of IOPS to provision for the disk. Valid io1 or io2. (default: `1000`)
* __General__
  * `name` - Prefix of hostname before index. (default: `node`)
  * `group` - Name of Ansible group to add hosts to.
  * `env` - Environment for these hosts, affects DNS entries.
  * `domain` - DNS Domain to update.
* __Security__
  * `vpc_id` - ID of the VPC for instances.
  * `subnet_id` - ID of the Subnet for instances.
  * `secgroup_id` - ID of the Security Group for instances.
  * `keypair_name` - User used to log in to instance (default: `root`)
  * `open_tcp_ports` - TCP port ranges to enable access from outside. Format: `N-N` (default: `[]`)
  * `open_udp_ports` - UDP port ranges to enable access from outside. Format: `N-N` (default: `[]`)
* __Protection__
  * `disable_api_stop` - Enables EC2 Instance Stop Protection. (default: `false`)
  * `disable_api_termination` - Enables EC2 Instance Termination Protection. (default: `false`)
  * `auto_recovery` - Automatic recovery behavior of the Instance. (default: `default`)
