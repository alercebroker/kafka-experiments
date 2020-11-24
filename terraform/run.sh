#! /bin/bash

export TF_VAR_private_key_path=/home/diego/.ssh/stamps.pem
export TF_VAR_pipeline_scale=8
export TF_VAR_simulator_scale=8

terraform plan
terraform apply
