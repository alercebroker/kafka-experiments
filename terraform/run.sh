#! /bin/bash

terraform destroy

export TF_VAR_private_key_path=/home/javier/.ssh/pem/stamps.pem
export TF_VAR_pipeline_scale=1
export TF_VAR_simulator_scale=1


terraform apply
