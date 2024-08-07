#!/bin/bash

set -euo pipefail

# EFS DNS name
EFS_DNS_NAME="$1"
EFS_AP_ID="$2"
MOUNT_POINT="$3"

add_to_fstab() {
  # Check if EFS entry already exists in /etc/fstab
  if ! grep -q "$EFS_DNS_NAME:/ $MOUNT_POINT" /etc/fstab; then
    # Add EFS to /etc/fstab
    # sudo echo "$EFS_DNS_NAME:/ $MOUNT_POINT efs accesspoint=$EFS_AP_ID,tls,_netdev,noresvport,iam 0 0" | sudo tee -a /etc/fstab  
    sudo echo "$EFS_DNS_NAME:/ $MOUNT_POINT nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" | sudo tee -a /etc/fstab
  else
    echo "EFS entry already exists in /etc/fstab"
  fi
}

mount_fs() {
  if [[ ! -d $MOUNT_POINT ]]; then
    sudo mkdir -p $MOUNT_POINT
    sudo chmod 644 $MOUNT_POINT
  fi

  sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "$EFS_DNS_NAME":/ "$MOUNT_POINT"
#   sudo mount -t efs -o noresvport,iam,tls,accesspoint=$EFS_AP_ID $EFS_DNS_NAME:/ $MOUNT_POINT
  mount | grep nfs
}

install_remount_service() {  
  # Check if check_efs_mount.service already exists
  if systemctl is-enabled check_efs_mount.service >/dev/null 2>&1; then
    echo "check_efs_mount.service already exists, skipping installation."
    return
  fi

  if [[ ! -d /opt/ml/scripts ]]; then
    mkdir -p /opt/ml/scripts && chmod 644 /opt/ml/scripts
    echo "Created dir /opt/ml/scripts"
  fi
  CHECK_MOUNT_FILE=/opt/ml/scripts/check_mount_efs.sh
  cat > $CHECK_MOUNT_FILE << EOF
#!/bin/bash
if ! grep -qs "127.0.0.1:/" /proc/mounts; then
  /usr/bin/mount -a
else
  systemctl stop check_efs_mount.timer
fi
EOF

  chmod +x $CHECK_MOUNT_FILE
  cat > /etc/systemd/system/check_efs_mount.service << EOF
[Unit]
Description=Check and remount efs filesystems if necessary
[Service]
ExecStart=$CHECK_MOUNT_FILE
EOF

  cat > /etc/systemd/system/check_efs_mount.timer << EOF
[Unit]
Description=Run check_efs_mount.service every minute
[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
[Install]
WantedBy=timers.target
EOF
}

main() {
  echo "mount_efs called with efs_dns_name: $EFS_DNS_NAME"
  echo "Using mount_point: $MOUNT_POINT"
#   check_already_mounted
  add_to_fstab
  mount_fs
  install_remount_service
  echo "EFS mounted successfully to $MOUNT_POINT through $EFS_AP_ID" 
}

main "$@"