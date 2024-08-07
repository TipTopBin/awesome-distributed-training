#!/bin/bash

set -euo pipefail

BUCKET_NAME="$1"
MOUNT_OPTIONS="$2"
MOUNT_POINT="$3"

check_mount_s3_installed() {
  # Check if mount-s3 is already installed
  if ! command -v mount-s3 >/dev/null 2>&1; then
    echo "Install mount-s3"
    cd /tmp
    wget https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.deb
    apt-get install -y -o DPkg::Lock::Timeout=120 ./mount-s3.deb
  else 
    echo "mount-s3 already installed"
  fi
}

add_to_s3tab() {
    local s3tab_file="/opt/ml/scripts/s3tab"

    if [ ! -d /opt/ml/scripts ]; then
        mkdir -p /opt/ml/scripts && chmod 644 /opt/ml/scripts
        touch "$s3tab_file"
        echo "Created $s3tab_file"
    fi

    # 使用文件锁防止并发写入
    (
        flock -s 200
        if ! grep -q "$BUCKET_NAME,$MOUNT_POINT,$MOUNT_OPTIONS" "$s3tab_file"; then
            echo "$BUCKET_NAME,$MOUNT_POINT,$MOUNT_OPTIONS" | tee -a "$s3tab_file"
        else
            echo "S3 entry already exists in $s3tab_file"
        fi
    ) 200>"$s3tab_file.lock"
}

mount_fs() {
  if [[ ! -d $MOUNT_POINT ]]; then
    sudo mkdir -p $MOUNT_POINT && sudo chmod 777 $MOUNT_POINT
  fi

  mount-s3 $BUCKET_NAME $MOUNT_OPTIONS $MOUNT_POINT
  mount | grep mountpoint-s3
}

install_remount_service() {  
  # Check if check_s3_mount.service already exists
  if systemctl is-enabled check_s3_mount.service >/dev/null 2>&1; then
    echo "check_s3_mount.service already exists, skipping installation."
    return
  fi

  CHECK_MOUNT_FILE=/opt/ml/scripts/check_mount_s3.sh  
  cat > $CHECK_MOUNT_FILE << EOF
#!/bin/bash

total_lines=\$(wc -l < /opt/ml/scripts/s3tab)
mounted_count=0

while IFS=',' read -r bucket_name mount_point mount_options; do
    if ! grep -qs "\$mount_point" /proc/mounts; then
        printf "Mounting %s to %s with options: %s\n" "\$bucket_name" "\$mount_point" "\$mount_options"    
        mkdir -p \$mount_point && chmod 777 \$mount_point
        mount-s3 \$bucket_name \$mount_options \$mount_point    
    fi
    ((mounted_count++))
done < /opt/ml/scripts/s3tab

if [ "\$mounted_count" -eq "\$total_lines" ]; then
    systemctl stop check_s3_mount.timer
    echo "All mount-s3 operations completed successfully"
else
    echo "\$mounted_count out of \$total_lines mount-s3 operations completed"
fi

EOF

  chmod +x $CHECK_MOUNT_FILE

  cat > /etc/systemd/system/check_s3_mount.service << EOF
[Unit]
Description=Mountpoint for Amazon S3 mount
[Service]
Type=forking
RemainAfterExit=yes
User=root
Group=root
ExecStart=$CHECK_MOUNT_FILE
[Install]
WantedBy=remote-fs.target
EOF

  cat > /etc/systemd/system/check_s3_mount.timer << EOF
[Unit]
Description=Run check_s3_mount.service every minute
[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now check_s3_mount.timer
}

main() {
  echo "mount_s3 called for bucket: $BUCKET_NAME with options: $MOUNT_OPTIONS, using mount_point: $MOUNT_POINT"  
  check_mount_s3_installed
  add_to_s3tab
  # mount_fs
  install_remount_service
}

main "$@"