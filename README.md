# kafka-experiments

This repository contains code for creating and running all the infrastructure necessary to run the kafka experiments, as well as running all software needed for consuming, producing, getting metrics, simulating pipeline steps, etc.

The idea of the experiment is to:

1. Produce messages using the LSST Schema
2. Consume these messages as a "dummy" step
3. Produce again
4. Repeat 2 and 3 with as many dummy steps as the real pipeline
5. Meassure rate of messages produced to each "dummy" step topic



## MongoDB Architecture.

This experiment will generate the following architecture on AWS.

![Diagram](./diagram.png)

## Repository structure.

- `ansible`: Playbooks and roles for different components
  - `playbooks`: Ansible playbooks to install and configure kafka, prometheus, runner and zookeeper
  - `roles`: Ansible roles for running different tasks
    - `docker`: Install docker
    - `grafana`: Install grafana and start with prometheus datasource and two preloaded dashboards, one for node_exporter metrics and one for kafka
    - `jmx_exporter`: Install and set jmx_exporter to export kafka metrics
    - `kafka`: Install and configure kafka
    - `node_exporter`: Install and configure node_exporter
    - `prometheus`: Install and configure prometheus
    - `run_experiments`: Clone experiment repository
    - `zookeeper`: Install and configure prometheus
- `dummmy_step`: Reference to [dummy_step repository](https://github.com/alercebroker/dummy_step)
- `packer`: Create AMIs with the tasks defined with Ansible.
- `terraform`: Create the EC2 instances using packer created AMIs and other infrastructure elements
- `vera_rubin_simulator`: Reference to [vera_rubin_simulator repository](https://github.com/alercebroker/vera_rubin_simulator)


## Requirements

### Ubuntu

1. Install Packer (https://learn.hashicorp.com/tutorials/packer/getting-started-install)

Add the HashiCorp Key
```sh
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
```

Add HashiCorp Linux repository.
```sh
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
```

Install Packer
```sh
sudo apt-get update && sudo apt-get install packer
```

2. Install Terraform

Using the same HashiCorp repository run.
```sh
sudo apt-get update && sudo apt-get install terraform
```

### Arch
1. Install Ansible
``` sh
sudo pacman -S ansible
```

1. Install Packer (https://learn.hashicorp.com/tutorials/packer/getting-started-install)
```sh
sudo pacman -S packer
```

2. Install Terraform
```sh
sudo pacman -S terraform
```


3. Create an AWS Token.

Create an AWS account with permissions to create resources (VPC, EC2, Subnets).

## Creating the AWS Image (AMI)

1. Configure environment variables:

    - `AWS_ACCESS_KEY_ID` : Amazon Access Key
    - `AWS_SECRET_ACCESS_KEY` : Amazon Secret
    - `INSTANCE_TYPE` : Instance type (for example t2.micro)

2. Create Image.

    Go to `packer` and run
    ```sh
    packer build zookeeper.json
    packer build kafka.json
    packer build runner.json
    packer build prometheus.json
    ```
3. Copy the output AMI ID from the terminal or AWS console.

## Set AMI ID from packer to each instance in `terraform/main.yml`

Replace ami parameter under each `resource "aws_instance"`

## Deploying Terraform on AWS

1. Enviroment Variables: All configurable variables are listed below, if no default defined terraform will prompt to get that variable.

- `TF_VAR_private_key_path` : Local path to key (i.e. ~/.ssh/keys/key.pem)

2. Plan the deploy
```sh
terraform plan
```

3. Deploy
```sh
terraform apply
```
This will deploy all resources in the terraform file, if a variable is changed after the apply just run apply again to update the infraestructure.


4. Watch the experiment in real time

Open a web browser and navigate to `<prometheus_public_ip>:3000` to enter the Grafana web application. There are two dashboards available. One for node_exporter metrics named `Node Exporter Full` and one for Kafka metrics named `KafkaOverview`.
