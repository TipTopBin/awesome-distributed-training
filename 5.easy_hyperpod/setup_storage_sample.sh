#!/bin/bash

# must be run a sudo
# set -ex

AWS_REGION="${AWS_REGION}"
HP_EFS_ID="${HP_EFS_ID}"
HP_EFS_MP="${HP_EFS_MP}" # MOUNT_POINT
HP_S3_BUCKET="${HP_S3_BUCKET}"
HP_S3_MP="${HP_S3_MP}"

main() {
    ## EFS
    if [ ! -z "$HP_EFS_ID" ]; then
        echo "Setup EFS"
        sudo mkdir -p $HP_EFS_MP
        sudo chmod 644 $HP_EFS_MP

        # sudo mount -t efs -o tls ${EFS_FS_ID}:/ /efs # Using the EFS mount helper
        sudo echo "${HP_EFS_ID}.efs.${AWS_REGION}.amazonaws.com:/ ${HP_EFS_MP} nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" | sudo tee -a /etc/fstab

        sudo mount -a
        sudo chown -hR +1000:+1000 $HP_EFS_MP*
        #sudo chmod 777 $HP_EFS_MP*
    fi

    ## S3 Mountpoint
    echo "Setup Mountpoint"
    wget https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.deb
    sudo apt-get install -y ./mount-s3.deb    
    # mount-s3 [OPTIONS] <BUCKET_NAME> <DIRECTORY>
    if [ ! -z "$HP_S3_BUCKET" ]; then
        mkdir -p $HP_S3_MP
        # sudo mount-s3 ${HP_S3_BUCKET} $HP_S3_MP --allow-other # 需要 root 权限
        sudo mount-s3 ${HP_S3_BUCKET} $HP_S3_MP --max-threads 96 --part-size 16777216 --allow-other --allow-delete --maximum-throughput-gbps 100 --dir-mode 777
    fi

    ## s5cmd
    # https://github.com/peak/s5cmd
    echo "Setup s5cmd"
    # export S5CMD_URL=$(curl -s https://api.github.com/repos/peak/s5cmd/releases/latest \
    # | grep "browser_download_url.*_Linux-64bit.tar.gz" \
    # | cut -d : -f 2,3 \
    # | tr -d \")
    # github has rate limit
    S5CMD_URL="https://github.com/peak/s5cmd/releases/download/v2.2.2/s5cmd_2.2.2_Linux-64bit.tar.gz"
    wget $S5CMD_URL -O /tmp/s5cmd.tar.gz
    sudo tar xzvf /tmp/s5cmd.tar.gz -C /usr/local/bin
}

main "$@"