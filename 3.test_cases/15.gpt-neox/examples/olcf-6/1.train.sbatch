#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#SBATCH --job-name="neox"
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=8
#SBATCH --gpus-per-node=8 # Number of GPU per node
#SBATCH --output=logs/%x_%j.out # logfile for stdout
#SBATCH --error=logs/%x_%j.err # logfile for stderr, remove it to merge both outputs
#SBATCH --wait-all-nodes=1
#SBATCH --exclusive
set -uxo pipefail

# default variables for Enroot, if these variables are defined then use them
: "${FSX_PATH:=/fsx}"
: "${IMAGE:=$FSX_PATH/apps/gpt-neox.sqsh}"
: "${CONTAINER_MOUNT:=$FSX_PATH:$FSX_PATH}"
## EFA settings
export FI_LOG_LEVEL=warn
export FI_PROVIDER=efa # change to eth if you want to use ENA for comparisons
export FI_EFA_USE_HUGE_PAGE=0
# https://discuss.pytorch.org/t/nccl-network-is-unreachable-connection-refused-when-initializing-ddp/137352
# https://github.com/pytorch/pytorch/issues/68893
export NCCL_SOCKET_IFNAME=en
export NCCL_ASYNC_ERROR_HANDLING=1
#export NCCL_DEBUG=INFO

export DATA_CONFIG=${PWD}/configs/frontier.yml
export MODEL_CONFIG=${PWD}/configs/forge-m.yml
# Some potentially useful distributed environment variables
export HOSTNAMES=`scontrol show hostnames "$SLURM_JOB_NODELIST"`
export MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)
export COUNT_NODE=`scontrol show hostnames "$SLURM_JOB_NODELIST" | wc -l`
export NODES=( $( scontrol show hostnames $SLURM_JOB_NODELIST ) )
export NODES_ARRAY=($NODES)
export HEAD_NODE=${NODES_ARRAY[0]}
export MASTER_ADDR=$(hostname --ip-address)
export MASTER_PORT=$RANDOM
export NNODES=$SLURM_JOB_NUM_NODES
export NPROC=$SLURM_GPUS_PER_NODE
export WORLD_SIZE=$(( $NNODES * $NPROC ))

declare -a ARGS=(
    --container-image $IMAGE
    --container-mounts $CONTAINER_MOUNT
)

declare -a TORCHRUN_ARGS=(
    # change this to match the number of gpus per node:
    --master_addr $MASTER_ADDR \
    --master_port $RANDOM \
    --nproc_per_node=8 \
    --nnodes=$SLURM_JOB_NUM_NODES \
    --rdzv_id=$SLURM_JOB_ID \
    --rdzv_backend=c10d \
    --rdzv_endpoint=$(hostname) \
)

srun -l "${ARGS[@]}" python deepy.py train.py ${MODEL_CONFIG} ${DATA_CONFIG}