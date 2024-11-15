#!/bin/bash
set -eux

sudo -u ec2-user -i <<'EOF'

CUSTOM_DIR=/home/ec2-user/SageMaker/custom
mkdir -p "$CUSTOM_DIR"/bin && mkdir -p "$CUSTOM_DIR"/logs
echo "export CUSTOM_DIR=${CUSTOM_DIR}" >> ~/SageMaker/custom/bashrc
echo "export CUSTOM_BASH=${CUSTOM_DIR}/bashrc" >> ~/SageMaker/custom/bashrc
echo 'export PATH=$PATH:/home/ec2-user/SageMaker/custom/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin' >> ~/SageMaker/custom/bashrc

EOF

# Under root
echo "Done ..."