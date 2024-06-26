#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

set -ex
# Mamba installed in shared FSx directory 
MAMBA_VERSION=23.1.0-1

curl -L -o ./mambaforge.sh https://github.com/conda-forge/miniforge/releases/download/${MAMBA_VERSION}/Mambaforge-${MAMBA_VERSION}-Linux-x86_64.sh
chmod +x ./mambaforge.sh
./mambaforge.sh -b -p ./conda
rm ./mambaforge.sh
./conda/bin/mamba clean -afy

source ./conda/bin/activate

conda create -n mambapretrain python=3.10
conda activate mambapretrain

# Install pytorch and other dependencies
#conda install -y pytorch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2 pytorch-cuda=11.8  --strict-channel-priority --override-channels -c https://aws-ml-conda.s3.us-west-2.amazonaws.com -c nvidia -c conda-forgea
#pip install causal-conv1d>=1.2.0
#pip install mamba-ssm

conda install -y pytorch==2.3.0 pytorch-cuda=11.8 -c pytorch -c nvidia
pip install -r requirements.txt
