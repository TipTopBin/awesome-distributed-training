#!/bin/bash

echo "==============================================="
echo "  ssh config ......"
echo "==============================================="
HOME_UBUNTU=$(eval echo ~ubuntu) # 启用 FSx，对应 /fsx/ubuntu，没有启用，则为 /home/ubuntu
echo "Ubuntu home directory: $HOME_UBUNTU"

PEM_FILE="pub.pem"
PEM_PRIV_FILE="priv.pem"
if [[ ! -f $PEM_FILE ]]; then
    echo "Shared user file $PEM_FILE does not exist. Skipping adding ssh pem."
else
    {
    cat $PEM_FILE|tr '\n' ' '
    } >> $HOME_UBUNTU/.ssh/authorized_keys
    cp $PEM_PRIV_FILE  $HOME_UBUNTU/.ssh/id_rsa
    chmod 400 $HOME_UBUNTU/.ssh/id_rsa
    chown ubuntu:ubuntu $HOME_UBUNTU/.ssh/id_rsa
fi

[[ -f /opt/slurm/etc/slurm.conf ]] \
    && SLURM_CONFIG=/opt/slurm/etc/slurm.conf \
    || SLURM_CONFIG=/var/spool/slurmd/conf-cache/slurm.conf

# https://github.com/aws-samples/aws-efa-nccl-baseami-pipeline/blob/9d8a9273f72d7dee36f7f3e5e8a968b5e0f5f21b/nvidia-efa-ami_base/nvidia-efa-ml-ubuntu2004.yml#L163-L169
cat << EOF >> /etc/ssh/ssh_config.d/initsmhp-ssh.conf
Host 127.0.0.1 localhost $(hostname)
    StrictHostKeyChecking no
    HostbasedAuthentication no
    CheckHostIP no
    UserKnownHostsFile /dev/null

Match host * exec "grep '^NodeName=%h ' $SLURM_CONFIG &> /dev/null"
    StrictHostKeyChecking no
    HostbasedAuthentication no
    CheckHostIP no
    UserKnownHostsFile /dev/null
EOF

# https://docs.aws.amazon.com/sagemaker/latest/dg/data-parallel-use-api.html
# echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config.new
# printf "Host *\n StrictHostKeyChecking no\n" >> /root/.ssh/config


echo "==============================================="
echo "  toolsets ......"
echo "==============================================="
echo "Add common tools"
sudo apt install net-tools


echo "Setup s5cmd"
# export S5CMD_URL=$(curl -s https://api.github.com/repos/peak/s5cmd/releases/latest \
# | grep "browser_download_url.*_Linux-64bit.tar.gz" \
# | cut -d : -f 2,3 \
# | tr -d \")
# github has rate limit
S5CMD_URL="https://github.com/peak/s5cmd/releases/download/v2.2.2/s5cmd_2.2.2_Linux-64bit.tar.gz"
wget $S5CMD_URL -O /tmp/s5cmd.tar.gz
sudo tar xzvf /tmp/s5cmd.tar.gz -C /usr/local/bin


