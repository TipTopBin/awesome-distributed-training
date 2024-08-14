#!/bin/bash

set -euo pipefail

# EFS DNS name
EFS_DNS_NAME="$1"
MOUNT_POINT="$2"
EFS_AP_ID="${3:-}"

if [ "$EFS_AP_ID" == "-" ]; then
    EFS_AP_ID=""
fi

check_efs_utils_installed() {
  # Check if efs-utils is already installed
  if ! command -v mount.efs &> /dev/null; then
    echo "Install efs-utils"
    # sudo apt-get update
    sudo apt-get -y install git binutils rustc cargo pkg-config libssl-dev
    git clone https://github.com/aws/efs-utils
    cd efs-utils
    # git checkout v2.0.3 # 切换到当前最新的 release
    ./build-deb.sh
    sudo apt-get -y install ./build/amazon-efs-utils*deb
  else 
    echo "efs-utils already installed"
  fi
}

add_to_fstab() {
  local mount_options="tls,_netdev,noresvport,iam"
  # local mount_options="nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev"
  if [[ -n "$EFS_AP_ID" ]]; then
    mount_options="$mount_options,accesspoint=$EFS_AP_ID"
  fi

  if ! grep -q "$EFS_DNS_NAME:/ $MOUNT_POINT" /etc/fstab; then
    echo "$EFS_DNS_NAME:/ $MOUNT_POINT efs $mount_options 0 0" | sudo tee -a /etc/fstab
  else
    echo "EFS entry already exists in /etc/fstab"
  fi  
}

mount_fs() {
  if [[ ! -d $MOUNT_POINT ]]; then
    sudo mkdir -p $MOUNT_POINT
    sudo chmod 644 $MOUNT_POINT
  fi

  local mount_options="noresvport,iam,tls"
  # local mount_options="nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport"

  if [[ -n "$EFS_AP_ID" ]]; then
    mount_options="$mount_options,accesspoint=$EFS_AP_ID"
  fi

  sudo mount -t efs -o "$mount_options" "$EFS_DNS_NAME":/ "$MOUNT_POINT"
  # sudo mount -t nfs4 -o "$mount_options" "$EFS_DNS_NAME":/ "$MOUNT_POINT"

  mount | grep -E "nfs|efs"
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

  systemctl daemon-reload
  systemctl enable --now check_efs_mount.timer
}

main() {
  echo "mount_efs called with efs_dns_name: $EFS_DNS_NAME"
  echo "Using mount_point: $MOUNT_POINT"
  check_efs_utils_installed
  add_to_fstab
  mount_fs
  install_remount_service

  if [[ -n "$EFS_AP_ID" ]]; then
    echo "EFS mounted successfully to $MOUNT_POINT through $EFS_AP_ID"
  else
    echo "EFS mounted successfully to $MOUNT_POINT"
  fi  
}

main "$@"