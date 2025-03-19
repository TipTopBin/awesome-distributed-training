#!/bin/bash

# power-ebs.sh - Resize root EBS volume and filesystem
# Usage: ./power-ebs.sh [size_GB] [iops] [throughput_MB]
# Default: 1000 GB, 6000 IOPS, 1000 MB/s throughput

set -e

# Parse command line arguments with defaults
SIZE=${1:-1000}
IOPS=${2:-6000}
THROUGHPUT=${3:-1000}

echo "============================================================"
echo "EBS Volume Resizing Tool"
echo "Target: $SIZE GB, $IOPS IOPS, $THROUGHPUT MB/s throughput"
echo "============================================================"

# Get IMDSv2 token and instance ID
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCEID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

if [ -z "$INSTANCEID" ]; then
    echo "Error: Failed to get Instance ID. Are you running on EC2?"
    exit 1
fi

echo "Instance ID: $INSTANCEID"

# Get the root EBS volume ID
VOLUMEID=$(aws ec2 describe-instances \
  --instance-id $INSTANCEID \
  --query "Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId" \
  --output text)

if [ -z "$VOLUMEID" ] || [ "$VOLUMEID" = "None" ]; then
    echo "Error: Failed to get volume ID"
    exit 1
fi

echo "Volume ID: $VOLUMEID"

# Modify the EBS volume
echo "Modifying EBS volume..."
aws ec2 modify-volume --volume-id $VOLUMEID \
    --volume-type gp3 \
    --size $SIZE \
    --iops $IOPS \
    --throughput $THROUGHPUT

# Wait for volume modification to start (no need to wait for full completion)
echo "Waiting for volume modification to initialize..."
while true; do
    STATE=$(aws ec2 describe-volumes-modifications \
      --volume-id $VOLUMEID \
      --query "VolumesModifications[0].ModificationState" \
      --output text)
    
    echo "Current state: $STATE"
    if [ "$STATE" = "optimizing" ] || [ "$STATE" = "completed" ]; then
        echo "Volume modification in progress or completed"
        break
    elif [ "$STATE" = "failed" ]; then
        echo "Volume modification failed!"
        exit 1
    fi
    sleep 5
done

echo "Proceeding with volume size $SIZE GB, IOPS $IOPS, throughput $THROUGHPUT MB/s"

# Detect root device
ROOT_DEVICE=$(findmnt -n -o SOURCE /)
echo "Root device is $ROOT_DEVICE"

# Extract the base device without partition number
if [[ $ROOT_DEVICE == *[0-9] ]]; then
    BASE_DEVICE=$(echo $ROOT_DEVICE | sed 's/[0-9]*$//')
    PARTITION_NUM=$(echo $ROOT_DEVICE | grep -o '[0-9]*$')
else
    BASE_DEVICE=$ROOT_DEVICE
    PARTITION_NUM=""
fi

# Handle different device naming conventions
if [[ $BASE_DEVICE == *"nvme"* ]]; then
    echo "NVMe device detected"
    DEVICE_PATH=$(echo $BASE_DEVICE | sed 's/p[0-9]*$//')
    PARTITION_PATH="${DEVICE_PATH}p${PARTITION_NUM}"
elif [[ $BASE_DEVICE == *"xvd"* ]] || [[ $BASE_DEVICE == *"sd"* ]]; then
    echo "XVD/SD device detected"
    DEVICE_PATH=$(echo $BASE_DEVICE | sed 's/[0-9]*$//')
    PARTITION_PATH="${DEVICE_PATH}${PARTITION_NUM}"
else
    echo "Unknown device type: $BASE_DEVICE"
    exit 1
fi

# Resize partition if needed
if [ -n "$PARTITION_NUM" ]; then
    echo "Resizing partition on $DEVICE_PATH partition $PARTITION_NUM..."
    sudo growpart $DEVICE_PATH $PARTITION_NUM || echo "Partition may already be resized"
fi

# Get filesystem type
FS_TYPE=$(findmnt -n -o FSTYPE /)
echo "Root filesystem type: $FS_TYPE"

# Resize filesystem based on type
echo "Resizing filesystem..."
case "$FS_TYPE" in
    "xfs")
        echo "XFS filesystem detected, using xfs_growfs"
        sudo xfs_growfs -d /
        ;;
    "ext4")
        echo "EXT4 filesystem detected, using resize2fs"
        sudo resize2fs $ROOT_DEVICE
        ;;
    "btrfs")
        echo "BTRFS filesystem detected, using btrfs filesystem resize"
        sudo btrfs filesystem resize max /
        ;;
    *)
        echo "Unsupported filesystem: $FS_TYPE"
        echo "Please resize the filesystem manually"
        exit 1
        ;;
esac

echo "============================================================"
echo "EBS volume and filesystem successfully resized!"
echo "New filesystem size: $(df -h / | awk 'NR==2 {print $2}')"
echo "============================================================"
