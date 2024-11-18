#!/bin/bash

source ~/.bashrc

CUSTOM_DIR=/home/ec2-user/SageMaker/custom
CUSTOM_BASH="${1:-/home/ec2-user/SageMaker/custom/bashrc}"

mkdir -p "$CUSTOM_DIR"/bin && \
  mkdir -p "$CUSTOM_DIR"/docker && \
  mkdir -p "$CUSTOM_DIR"/envs && \
  mkdir -p "$CUSTOM_DIR"/vscode && \
  mkdir -p "$CUSTOM_DIR"/tmp && \
  mkdir -p "$CUSTOM_DIR"/logs

# if [ ! -d "$CUSTOM_DIR" ]; then
if ! grep -q "CUSTOM_BASH" $CUSTOM_BASH; then
  echo "Set custom dir and bashrc"
  sudo chmod 777 "$CUSTOM_DIR"/tmp
  # touch ${CUSTOM_DIR}/bash_history

  echo "export CUSTOM_DIR=${CUSTOM_DIR}" >> $CUSTOM_BASH
  echo "export CUSTOM_BASH=${CUSTOM_BASH}" >> $CUSTOM_BASH
  # Relocate pipx packages to ~/SageMaker to survive reboot
  echo "export PIPX_HOME=~/SageMaker/custom/pipx" >> $CUSTOM_BASH
  echo "export PIPX_BIN_DIR=~/SageMaker/custom/bin" >> $CUSTOM_BASH
  # Add pipx binaries to PATH. In addition, add also ~/.local/bin so that its
  # commands are usable by Jupyter kernels (notable example: docker-compose for SageMaker local mode).
  echo 'export PATH=$PATH:/home/ec2-user/SageMaker/custom/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin:/home/ec2-user/.local/bin' >> $CUSTOM_BASH
fi


echo "==============================================="
echo "  Load custom bashrc and ssh ......"
echo "==============================================="
# PS1 must preceed conda bash.hook, to correctly display CONDA_PROMPT_MODIFIER
# 路径显示更简洁 (base) [ec2-user@ip-172-16-48-86 custom]$ -> (base) [~/SageMaker/custom] $ 
cp ~/.bashrc{,.ori} # 备份原 .bashrc
cat << 'EOF' > ~/.bashrc
git_branch() {
   local branch=$(/usr/bin/git branch 2>/dev/null | grep '^*' | colrm 1 2)
   [[ "$branch" == "" ]] && echo "" || echo "($branch) "
}

# Put before PS1 to effect and all colors are bold
COLOR_GREEN="\[\033[1;32m\]"
COLOR_PURPLE="\[\033[1;35m\]"
COLOR_YELLOW="\[\033[1;33m\]"
COLOR_OFF="\[\033[0m\]"

# Define PS1 before conda bash.hook, to correctly display CONDA_PROMPT_MODIFIER
export PS1="[$COLOR_GREEN\w$COLOR_OFF] $COLOR_PURPLE\$(git_branch)$COLOR_OFF\$ "

EOF

# Add back original .bashrc content
cat ~/.bashrc.ori >> ~/.bashrc

# Add custom bash file if not set before
cat >> ~/.bashrc <<EOF

bashrc_files=(bashrc)
path="/home/ec2-user/SageMaker/custom/"
for file in \${bashrc_files[@]}
do 
    file_to_load=\$path\$file
    if [ -f "\$file_to_load" ];
    then
        . \$file_to_load
        echo "loaded \$file_to_load"
    fi
done
EOF

# persistent vscode extensions
ln -s $CUSTOM_DIR/vscode ~/.vscode-server
# 如果遇到 scp: Received message too long xxx, 本地 vscode 连不上，可以先移动一下 bash 文件

source ~/.bashrc

# check if a ENV ACCOUNT_ID exist
if [ -z "${MY_AZ}" ]; then
  echo "Add envs: ACCOUNT_ID AWS_REGION MY_AZ"
  # ACCOUNT_ID=$(aws sts get-caller-identity | grep Account | awk '{print $2}' | sed -e 's/"//g' -e 's/,//g')

  MY_AZ=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
  if [[ $MY_AZ == "" ]]; then
    # IMDSv2
    IMDS_TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
    MY_AZ=`curl -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
  fi
  # AWS_REGION="`echo \"$MY_AZ\" | sed 's/[a-z]\$//'`"

  cat >> $CUSTOM_BASH <<EOF  

export AWS_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export MY_AZ=${MY_AZ}

EOF
fi


source ~/.bashrc

test -n "$AWS_REGION" && echo AWS_REGION is "$AWS_REGION" || echo AWS_REGION is not set
aws configure set default.region ${AWS_REGION}
aws configure get default.region
aws configure set region $AWS_REGION
aws configure set default.s3.preferred_transfer_client crt

if [ -z "${FLAVOR}" ]; then
  echo "Add env: FLAVOR"
  cat >> $CUSTOM_BASH <<EOF
FLAVOR="$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f 2)"

EOF
fi


# SSH 放在脚本靠前位置，方便调试
if [ -f /home/ec2-user/SageMaker/custom/private_key.pem ]
then
  echo "Setup SSH Keys"
  sudo cp /home/ec2-user/SageMaker/custom/private_key.pem ~/.ssh/id_rsa
  sudo cp /home/ec2-user/SageMaker/custom/public_key.pem ~/.ssh/id_rsa.pub
  sudo chmod 400 ~/.ssh/id_rsa
  sudo chown -R ec2-user:ec2-user ~/.ssh/
  # ssh-keygen -f ~/.ssh/id_rsa -y > ~/.ssh/id_rsa.pub

  # 本地免密，方便 EKS Node 能反向 SSH 到 Notebook Instance
  {
  cat ~/.ssh/id_rsa.pub|tr '\n' ' '
  } >> ~/.ssh/authorized_keys

  # SSH Forward
  sudo adduser ubuntu
  sudo mkdir -p /home/ubuntu/.ssh
  sudo cp /home/ec2-user/.ssh/* /home/ubuntu/.ssh/
  sudo chown -R ubuntu /home/ubuntu*
fi
# sagemaker-hyperpod ssh
# https://catalog.workshops.aws/sagemaker-hyperpod/en-US/01-cluster/05-ssh
if [ ! -f $CUSTOM_DIR/bin/easy-ssh ]; then
  wget -O $CUSTOM_DIR/bin/easy-ssh https://raw.githubusercontent.com/TipTopBin/awesome-distributed-training/main/1.architectures/5.sagemaker-hyperpod/easy-ssh.sh
  chmod +x $CUSTOM_DIR/bin/easy-ssh
fi
# easy-ssh -h
# easy-ssh -c controller-group cluster-name


echo "==============================================="
echo "  Performance config ......"
echo "==============================================="
sudo bash -c 'cat >> /etc/sysctl.conf' << EOF
fs.inotify.max_user_watches=520088
EOF
sudo sysctl -p
cat /proc/sys/fs/inotify/max_user_watches

# yum
sudo yum-config-manager --disable centos-extras
grep '^max_connections=' /etc/yum.conf &> /dev/null || echo "max_connections=10" | sudo tee -a /etc/yum.conf


echo "==============================================="
echo "  Utilities ......"
echo "==============================================="
# moreutils: The command sponge allows us to read and write to the same file (cat a.txt|sponge a.txt)
sudo amazon-linux-extras install epel -y
sudo yum-config-manager --add-repo=https://copr.fedorainfracloud.org/coprs/cyqsimon/el-rust-pkgs/repo/epel-7/cyqsimon-el-rust-pkgs-epel-7.repo
#sudo yum update -y  # Disable. It's slow to update 100+ SageMaker-provided packages.
sudo yum groupinstall "Development Tools" -y
sudo yum -y install \
    jq \
    gettext \
    bash-completion \
    moreutils \
    openssl \
    tree \
    zsh \
    xsel \
    xclip \
    amazon-efs-utils \
    nc \
    telnet \
    mtr \
    traceroute \
    netcat
sudo yum install -y \
    htop \
    tree \
    fio \
    ioping \
    dstat \
    siege \
    dos2unix \
    tig \
    ncdu \
    ripgrep \
    bat \
    git-delta \
    inxi \
    mediainfo \
    git-lfs \
    nvme-cli \
    aria2


if [ ! -f $CUSTOM_DIR/bin/yq ]; then
  wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O $CUSTOM_DIR/bin/yq
  chmod +x $CUSTOM_DIR/bin/yq
fi


# Upgrade awscli to v2
if [ ! -f $CUSTOM_DIR/bin/awscliv2.zip ]; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$CUSTOM_DIR/bin/awscliv2.zip"
  # unzip -qq awscliv2.zip -C
  unzip -o $CUSTOM_DIR/bin/awscliv2.zip -d $CUSTOM_DIR/bin
fi
sudo $CUSTOM_DIR/bin/aws/install --update
rm -f /home/ec2-user/anaconda3/envs/JupyterSystemEnv/bin/aws
sudo mv ~/anaconda3/bin/aws ~/anaconda3/bin/aws1
ls -l /usr/local/bin/aws
source ~/.bashrc
aws --version
# # Catch-up with awscliv2 which has nearly weekly releases. 
# aria2c -x5 --dir /tmp -o awscli2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
# cd /tmp && unzip -o -q /tmp/awscli2.zip
# aws/install --update --install-dir ~/SageMaker/custom/aws-cli-v2 --bin-dir ~/SageMaker/custom/bin
# sudo ln -s ~/SageMaker/custom/bin/aws /usr/local/bin/aws2 || true
# rm /tmp/awscli2.zip
# rm -fr /tmp/aws/
# export AWS_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
aws configure set default.region ${AWS_REGION}
aws configure get default.region
aws configure set region $AWS_REGION
# refer from aws-samples hpc repo
aws configure set default.s3.max_concurrent_requests 100
aws configure set default.s3.max_queue_size 10000
aws configure set default.s3.multipart_threshold 64MB
aws configure set default.s3.multipart_chunksize 16MB
# aws configure set default.cli_auto_prompt on-partial


# Install session-manager
if [ ! -f $CUSTOM_DIR/bin/session-manager-plugin.rpm ]; then
  curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "$CUSTOM_DIR/bin/session-manager-plugin.rpm"
fi
sudo yum install -y $CUSTOM_DIR/bin/session-manager-plugin.rpm
session-manager-plugin

# ec2-instance-selector
if [ ! -f $CUSTOM_DIR/bin/ec2-instance-selector ]; then
  target=$(uname | tr '[:upper:]' '[:lower:]')-amd64
  LATEST_DOWNLOAD_URL=$(curl --silent $CUSTOM_DIR/bin/ec2-instance-selector "https://api.github.com/repos/aws/amazon-ec2-instance-selector/releases/latest" | grep "\"browser_download_url\": \"https.*$target.tar.gz" | sed -E 's/.*"([^"]+)".*/\1/')
  curl -Lo $CUSTOM_DIR/bin/ec2-instance-selector.tar.gz $LATEST_DOWNLOAD_URL
  tar -xvf $CUSTOM_DIR/bin/ec2-instance-selector.tar.gz -C $CUSTOM_DIR/bin
  # curl -Lo $CUSTOM_DIR/bin/ec2-instance-selector https://github.com/aws/amazon-ec2-instance-selector/releases/download/v2.4.1/ec2-instance-selector-`uname | tr '[:upper:]' '[:lower:]'`-amd64 
  chmod +x $CUSTOM_DIR/bin/ec2-instance-selector
fi


# S3 mountpoint
if [ ! -f $CUSTOM_DIR/bin/mount-s3.rpm ]; then
  wget -O $CUSTOM_DIR/bin/mount-s3.rpm https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.rpm
fi
sudo yum install -y $CUSTOM_DIR/bin/mount-s3.rpm


# s5cmd
# https://github.com/peak/s5cmd
if [ ! -f $CUSTOM_DIR/bin/s5cmd ]; then
    echo "Setup s5cmd"
    S5CMD_URL="https://github.com/peak/s5cmd/releases/download/v2.2.2/s5cmd_2.2.2_Linux-64bit.tar.gz"
    wget $S5CMD_URL -O /tmp/s5cmd.tar.gz
    sudo tar xzvf /tmp/s5cmd.tar.gz -C $CUSTOM_DIR/bin
fi
# mv/sync 等注意要加单引号，注意区域配置
# s5cmd mv 's3://xxx-iad/HFDatasets/*' 's3://xxx-iad/datasets/HF/'
# s5 --profile=xxx cp --source-region=us-west-2 s3://xxx.zip ./xxx.zip


# https://github.com/muesli/duf
echo "Setup duf"
if [ ! -f $CUSTOM_DIR/bin/duf.rpm ]; then
    DOWNLOAD_URL="https://github.com/muesli/duf/releases/download/v0.8.1/duf_0.8.1_linux_amd64.rpm"
    wget $DOWNLOAD_URL -O $CUSTOM_DIR/bin/duf.rpm
fi
sudo yum localinstall -y $CUSTOM_DIR/bin/duf.rpm


echo "==============================================="
echo "  Container tools ......"
echo "==============================================="
ARCH=amd64 # for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
PLATFORM=$(uname -s)_$ARCH
if [ ! -f $CUSTOM_DIR/bin/eksctl_$PLATFORM.tar.gz ]; then
  curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz" -o $CUSTOM_DIR/bin/eksctl_$PLATFORM.tar.gz
  tar -xzf $CUSTOM_DIR/bin/eksctl_$PLATFORM.tar.gz -C $CUSTOM_DIR/bin
fi
# old eksctl for upgrade testing
# if [ ! -f $CUSTOM_DIR/bin/eksctl_150.tar.gz ]; then
#   curl -sL "https://github.com/eksctl-io/eksctl/releases/download/v0.150.0/eksctl_Linux_amd64.tar.gz" -o $CUSTOM_DIR/bin/eksctl_150.tar.gz
#   tar -xzf $CUSTOM_DIR/bin/eksctl_150.tar.gz
#   mv eksctl $CUSTOM_DIR/bin/eksctl150
# fi

if [ ! -f $CUSTOM_DIR/bin/kubectl ]; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  mv kubectl /tmp/
  sudo install -o root -g root -m 0755 /tmp/kubectl $CUSTOM_DIR/bin/kubectl
fi

if [ ! -f $CUSTOM_DIR/bin/get_helm.sh ]; then
  curl -fsSL -o $CUSTOM_DIR/bin/get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
  chmod 700 $CUSTOM_DIR/bin/get_helm.sh
fi
$CUSTOM_DIR/bin/get_helm.sh
helm version
helm repo add eks https://aws.github.io/eks-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo update
# docker logout public.ecr.aws
helm registry logout public.ecr.aws

if [ ! -f $CUSTOM_DIR/bin/kubectl-karpenter.sh ]; then
  curl -fsSL -o $CUSTOM_DIR/bin/kubectl-karpenter.sh https://raw.githubusercontent.com/TipTopBin/aws-do-eks/main/utils/kubectl-karpenter.sh
  chmod +x $CUSTOM_DIR/bin/kubectl-karpenter.sh
fi

curl -sS https://webinstall.dev/k9s | bash

if [ ! -f $CUSTOM_DIR/bin/kubetail ]; then
  curl -o $CUSTOM_DIR/bin/kubetail https://raw.githubusercontent.com/johanhaleby/kubetail/master/kubetail
  chmod +x $CUSTOM_DIR/bin/kubetail
fi

if [ ! -f $CUSTOM_DIR/bin/kustomize ]; then
  curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash
  sudo mv -v kustomize $CUSTOM_DIR/bin
fi
kustomize version

if [ ! -f $CUSTOM_DIR/bin/kubie ]; then
  wget https://github.com/sbstp/kubie/releases/latest/download/kubie-linux-amd64 -O $CUSTOM_DIR/bin/kubie
  chmod +x $CUSTOM_DIR/bin/kubie
fi


# krew
if [ ! -d $CUSTOM_DIR/bin/krew ]; then
  export KREW_ROOT="$CUSTOM_DIR/bin/krew"
  (
    set -x; cd "$(mktemp -d)" &&
    OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
    KREW="krew-${OS}_${ARCH}" &&
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
    tar zxvf "${KREW}.tar.gz" &&
    ./"${KREW}" install krew
  )

  export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
  kubectl krew update
  kubectl krew install ctx # kubectx
  kubectl krew install ns # kubens
fi


# # run this script on your eks node
# if [ ! -f $CUSTOM_DIR/bin/eks-log-collector.sh ]; then
#   curl -o $CUSTOM_DIR/bin/eks-log-collector.sh https://raw.githubusercontent.com/awslabs/amazon-eks-ami/master/log-collector-script/linux/eks-log-collector.sh 
#   chmod +x $CUSTOM_DIR/bin/eks-log-collector.sh
# fi

# AMI
# export ACCELERATED_AMI=$(aws ssm get-parameter \
#     --name /aws/service/eks/optimized-ami/$EKS_VERSION/amazon-linux-2-gpu/recommended/image_id \
#     --region $AWS_REGION \
#     --query "Parameter.Value" \
#     --output text)


# k8sgpt
if [ ! -f $CUSTOM_DIR/bin/k8sgpt_Linux_x86_64.tar.gz ]; then
  wget -O $CUSTOM_DIR/bin/k8sgpt_Linux_x86_64.tar.gz https://github.com/k8sgpt-ai/k8sgpt/releases/download/v0.3.25/k8sgpt_Linux_x86_64.tar.gz
  tar -xvf $CUSTOM_DIR/bin/k8sgpt_Linux_x86_64.tar.gz -C $CUSTOM_DIR/bin
fi
# k8sgpt auth add --backend amazonbedrock --model anthropic.claude-v2
# k8sgpt auth list
# k8sgpt auth default -p amazonbedrock


# docker 
sudo rm /etc/yum.repos.d/docker-ce.repo || true # Lots of problem, from wrong .repo content to broken selinux-container
# tmp dir
# Give docker build a bit more space. E.g., as of Nov'21, building a custom
# image based on the pytorch-1.10 DLC would fail due to exhausted /tmp.
sudo sed -i \
    's|^\[Service\]$|[Service]\nEnvironment="DOCKER_TMPDIR=/home/ec2-user/SageMaker/custom/tmp"|' \
    /usr/lib/systemd/system/docker.service
# change docker data root
sudo ~ec2-user/anaconda3/bin/python -c "
import json

with open('/etc/docker/daemon.json') as f:
    d = json.load(f)

d['data-root'] = '/home/ec2-user/SageMaker/custom/docker'

with open('/etc/docker/daemon.json', 'w') as f:
    json.dump(d, f, indent=4)
    f.write('\n')
"
# https://docs.aws.amazon.com/sagemaker/latest/dg/docker-containers-troubleshooting.html
mkdir -p ~/.sagemaker
cat > ~/.sagemaker/config.yaml <<EOF
local:
  container_root: /home/ec2-user/SageMaker/tmp
EOF
# restart docker
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl show --property=Environment docker
# Allow ec2-user access to the new tmp (which belongs to ec2-user anyway).
# sudo chmod 777  /home/ec2-user/SageMaker/tmp/
# sudo rm -fr  /home/ec2-user/SageMaker/tmp/*


# # Docker Compose
ln -s ~/anaconda3/bin/docker-compose ~/.local/bin/
# #sudo curl -L https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
# sudo mkdir -p /usr/local/lib/docker/cli-plugins/
# sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
# sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
# # sudo curl -L https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m) -o $CUSTOM_DIR/docker-compose
# # sudo chmod +x $CUSTOM_DIR/docker-compose
# # $CUSTOM_DIR/docker-compose version
# local mode
# curl -sfL \
#     https://raw.githubusercontent.com/aws-samples/amazon-sagemaker-local-mode/main/blog/pytorch_cnn_cifar10/setup.sh \
#     | /bin/bash -s


# echo "  Install eks anywhere ......"
# export EKSA_RELEASE="0.14.3" OS="$(uname -s | tr A-Z a-z)" RELEASE_NUMBER=30
# curl "https://anywhere-assets.eks.amazonaws.com/releases/eks-a/${RELEASE_NUMBER}/artifacts/eks-a/v${EKSA_RELEASE}/${OS}/amd64/eksctl-anywhere-v${EKSA_RELEASE}-${OS}-amd64.tar.gz" \
#     --silent --location \
#     | tar xz ./eksctl-anywhere
# sudo mv ./eksctl-anywhere /usr/local/bin/
# eksctl anywhere version


# echo "  Install copilot ......"
# sudo curl -Lo /usr/local/bin/copilot https://github.com/aws/copilot-cli/releases/latest/download/copilot-linux \
#    && sudo chmod +x /usr/local/bin/copilot \
#    && copilot --help


# echo "  Install App2Container ......"
# #https://docs.aws.amazon.com/app2container/latest/UserGuide/start-step1-install.html
# #https://aws.amazon.com/blogs/containers/modernize-java-and-net-applications-remotely-using-aws-app2container/
# curl -o /tmp/AWSApp2Container-installer-linux.tar.gz https://app2container-release-us-east-1.s3.us-east-1.amazonaws.com/latest/linux/AWSApp2Container-installer-linux.tar.gz
# sudo tar xvf /tmp/AWSApp2Container-installer-linux.tar.gz -C /tmp
# # sudo ./install.sh
# echo y |sudo /tmp/install.sh
# sudo app2container --version
# cat >> ~/.bashrc <<EOF
# alias a2c="sudo app2container"
# EOF
# source ~/.bashrc
# a2c help
# curl -o /tmp/optimizeImage.zip https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/samples/p-attach/dc756bff-1fcd-4fd2-8c4f-dc494b5007b9/attachments/attachment.zip
# sudo unzip /tmp/optimizeImage.zip -d /tmp/optimizeImage
# sudo chmod 755 /tmp/optimizeImage/optimizeImage.sh
# sudo mv /tmp/optimizeImage/optimizeImage.sh /usr/local/bin/optimizeImage.sh
# optimizeImage.sh -h


# echo "  Install kube-no-trouble (kubent) ......"
# # https://github.com/doitintl/kube-no-trouble
# # https://medium.doit-intl.com/kubernetes-how-to-automatically-detect-and-deal-with-deprecated-apis-f9a8fc23444c
# sh -c "$(curl -sSL https://git.io/install-kubent)"


# echo "  Install IAM Authenticator ......"
## https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html
## curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.15.10/2020-02-22/bin/linux/amd64/aws-iam-authenticator
## curl -o aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.5.9/aws-iam-authenticator_0.5.9_linux_amd64
# curl -o aws-iam-authenticator https://s3.us-west-2.amazonaws.com/amazon-eks/1.21.2/2021-07-05/bin/linux/amd64/aws-iam-authenticator
# chmod +x ./aws-iam-authenticator
# mkdir -p $HOME/bin && mv ./aws-iam-authenticator $HOME/bin/aws-iam-authenticator && export PATH=$PATH:$HOME/bin
# echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
# source ~/.bashrc
# aws-iam-authenticator help


# echo "  Install kubescape ......"
# # curl -s https://raw.githubusercontent.com/armosec/kubescape/master/install.sh | /bin/bash
# curl -s https://raw.githubusercontent.com/armosec/kubescape/master/install.sh -o "/tmp/kubescape.sh"
# /tmp/kubescape.sh


# echo "  Install kind ......"
# curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.17.0/kind-$(uname)-amd64"
# chmod +x ./kind
# sudo mv ./kind /usr/local/bin/kind


# echo "  Install Flux CLI ......"
# curl -s https://fluxcd.io/install.sh | sudo bash
# flux --version


# echo "  Install argocd ......"
# # curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
# # sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
# # rm argocd-linux-amd64
# # argocd version --client
# export ARGO_VERSION="v3.4.9"
# curl -sLO https://github.com/argoproj/argo-workflows/releases/download/${ARGO_VERSION}/argo-linux-amd64.gz
# gunzip argo-linux-amd64.gz
# chmod +x argo-linux-amd64
# sudo mv ./argo-linux-amd64 /usr/local/bin/argo
# argo version
# rm -fr argo-linux-amd64.gz
# # # Install Argo Rollout
# # sudo curl -Lo /usr/local/bin/kubectl-argo-rollouts https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
# # sudo chmod +x /usr/local/bin/kubectl-argo-rollouts


# echo "  Install docker buildx ......"
# # https://aws.amazon.com/blogs/compute/how-to-quickly-setup-an-experimental-environment-to-run-containers-on-x86-and-aws-graviton2-based-amazon-ec2-instances-effort-to-port-a-container-based-application-from-x86-to-graviton2/
# # https://docs.docker.com/build/buildx/install/
# # export DOCKER_BUILDKIT=1
# # docker build --platform=local -o . git://github.com/docker/buildx
# DOCKER_BUILDKIT=1 docker build --platform=local -o . "https://github.com/docker/buildx.git"
# mkdir -p ~/.docker/cli-plugins
# mv buildx ~/.docker/cli-plugins/docker-buildx
# chmod a+x ~/.docker/cli-plugins/docker-buildx
# docker run --privileged --rm tonistiigi/binfmt --install all
# docker buildx ls


# 编译安装时间较久，如需要请手动复制脚本安装
# echo "  Install kmf ......"
# git clone https://github.com/awslabs/aws-kubernetes-migration-factory
# cd aws-kubernetes-migration-factory/
# sudo go build -o /usr/local/bin/kmf
# cd ..
# kmf -h


# echo "  Install clusterctl ......"
# curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.2.4/clusterctl-linux-amd64 -o clusterctl
# chmod +x ./clusterctl
# sudo mv ./clusterctl /usr/local/bin/clusterctl
# clusterctl version


# echo "  Install clusterawsadm ......"
# curl -L https://github.com/kubernetes-sigs/cluster-api-provider-aws/releases/download/v1.5.0/clusterawsadm-linux-amd64 -o clusterawsadm
# chmod +x clusterawsadm
# sudo mv clusterawsadm /usr/local/bin
# clusterawsadm version


# echo "  Install kube-ps1.sh ......"
# curl -L -o ~/kube-ps1.sh https://github.com/jonmosco/kube-ps1/raw/master/kube-ps1.sh
# cat << EOF >> ~/.bashrc
# alias kon='touch ~/.kubeon; source ~/.bashrc'
# alias koff='rm -f ~/.kubeon; source ~/.bashrc'
# if [ -f ~/.kubeon ]; then
#         source ~/kube-ps1.sh
#         PS1='[\u@\h \W \$(kube_ps1)]\$ '
# fi
# EOF
# source ~/.bashrc


# echo "  Cloudwatch Dashboard Generator ......"
# https://github.com/aws-samples/aws-cloudwatch-dashboard-generator
# mkdir -p ~/environment/sre && cd ~/environment/sre
# # git clone https://github.com/aws-samples/aws-cloudwatch-dashboard-generator.git 
# git clone https://github.com/CLOUDCNTOP/aws-cloudwatch-dashboard-generator.git
# cd aws-cloudwatch-dashboard-generator
# pip install -r r_requirements.txt


# echo " krr (Prometheus-based Kubernetes Resource Recommendations) ......"
#https://github.com/robusta-dev/krr


# echo " tumx ......"
#https://tmuxcheatsheet.com/
#https://github.com/MarcoLeongDev/handsfree-stable-diffusion


# echo " eksdemo ......"
# https://github.com/awslabs/eksdemo

# echo " kubefirst ......"
# https://github.com/kubefirst/kubefirst
# https://docs.kubefirst.io/aws/overview


# echo " Steampipe ......"
# Visualizing AWS EKS Kubernetes Clusters with Relationship Graphs
# https://dev.to/aws-builders/visualizing-aws-eks-kubernetes-clusters-with-relationship-graphs-46a4
# sudo /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/turbot/steampipe/main/install.sh)"
# steampipe plugin install kubernetes
# git clone https://github.com/turbot/steampipe-mod-kubernetes-insights
# cd steampipe-mod-kubernetes-insights
# steampipe dashboard


# echo " kuboard ......"
# https://kuboard.cn/install/v3/install-built-in.html#%E9%83%A8%E7%BD%B2%E8%AE%A1%E5%88%92
# LOCAL_IPV4=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
# sudo docker run -d \
#   --restart=unless-stopped \
#   --name=kuboard \
#   -p 80:80/tcp \
#   -p 10081:10081/tcp \
#   -e KUBOARD_ENDPOINT="http://${LOCAL_IPV4}:80" \
#   -e KUBOARD_AGENT_SERVER_TCP_PORT="10081" \
#   -v /root/kuboard-data:/data \
#   eipwork/kuboard:v3
  # 也可以使用镜像 swr.cn-east-2.myhuaweicloud.com/kuboard/kuboard:v3 ，可以更快地完成镜像下载。
  # 请不要使用 127.0.0.1 或者 localhost 作为内网 IP \
  # Kuboard 不需要和 K8S 在同一个网段，Kuboard Agent 甚至可以通过代理访问 Kuboard Server \

# echo "  KubeVela ......"
# https://kubevela.io/docs/installation/standalone/#local


echo "==============================================="
echo "  Load custom config ......"
echo "==============================================="
# EKS
if [ ! -z "$EKS_CLUSTER_NAME" ]; then
    # aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}
    /usr/local/bin/aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}
fi


# S3 bucket
# mount-s3 [OPTIONS] <BUCKET_NAME> <DIRECTORY>
if [ ! -z "$S3_INTG_AUTO" ]; then
    mkdir -p /home/ec2-user/SageMaker/s3/${S3_INTG_AUTO}
    mount-s3 ${S3_INTG_AUTO} /home/ec2-user/SageMaker/s3/${S3_INTG_AUTO} --allow-delete --dir-mode 777
    # fusermount: option allow_other only allowed if 'user_allow_other' is set in /etc/fuse.conf
    # sudo mount-s3 ${HP_S3_BUCKET} $HP_S3_MP --max-threads 96 --part-size 16777216 --allow-other --allow-delete --maximum-throughput-gbps 100 --dir-mode 777
fi


# EFS
if [ ! -z "$EFS_FS_ID" ]; then
  mkdir -p /home/ec2-user/SageMaker/efs/${EFS_FS_NAME}
  echo "${EFS_FS_ID}.efs.${AWS_REGION}.amazonaws.com:/ /home/ec2-user/SageMaker/efs/${EFS_FS_NAME} nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" | sudo tee -a /etc/fstab # NFS
  # echo "${EFS_FS_ID}.efs.${AWS_REGION}.amazonaws.com:/ /home/ec2-user/SageMaker/efs/${EFS_FS_NAME} efs _netdev,tls 0 0" | sudo tee -a /etc/fstab # Using the EFS mount helper
  sudo mount -a
  #sudo chown -hR +1000:+1000 /home/ec2-user/SageMaker/efs*
  #sudo chmod 777 /home/ec2-user/SageMaker/efs*
fi


# Instance store
# Install NVMe CLI
sudo yum install nvme-cli mdadm -y

# Get drives string
instance_drives=$(sudo nvme list | grep "Amazon EC2 NVMe Instance Storage" | cut -d " " -f 1 || true)
# Convert to array

readarray -t instance_drives <<< "$instance_drives"
num_drives=-1
[[ ! -z "$instance_drives" ]] && num_drives=${#instance_drives[@]} || num_drives=0
echo ${instance_drives[@]} $num_drives

mount_location="/opt/dlami/nvme"
sudo mkdir -p $mount_location

if [ $num_drives -gt 1 ]
then
  echo "${num_drives} extra devices found."

  sudo mdadm --create /dev/md0 --level=0 --name=md0 --raid-devices=$num_drives "${instance_drives[@]}"

  # Format drive with xfs 
  sudo mkfs.xfs /dev/md0

  uuid=$(sudo blkid -o value -s UUID /dev/md0)

  # Create a filesystem path to mount the disk    
  sudo mount /dev/md0 $mount_location

  # Have disk be mounted on reboot
  sudo mdadm --detail --scan | sudo tee -a /etc/mdadm.conf 
  echo "/dev/md0 $mount_location xfs defaults,noatime 0 2" | sudo tee -a /etc/fstab

elif [ $num_drives -gt 0 ]
then
  echo "1 extra device found."

  device=${instance_drives[0]}
  sudo mkfs.xfs ${device}

  echo "${device} ${mount_location} xfs defaults,noatime 1 2" | sudo tee -a /etc/fstab

else
  echo "No extra device found."
fi

sudo mount -a
sudo chown -hR +1000:+1000 /opt/dlami/*


# Git
if [ ! -z "$GIT_USER" ]; then
  echo "setup git user"
  git config --global user.name ${GIT_USER}
  git config --global user.email ${GIT_MAIL}  
fi
# env GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no"
cat >> ~/.gitconfig <<EOF
[alias]
    pcp = "!git pull && git add . && read -p 'Enter commit message: ' commit_message && git commit -m \"\$commit_message\" && git push"
EOF
echo 'Set editor to /usr/bin/vim (for DL AMI)'
git config --global core.editor /usr/bin/vim
echo 'Set default branch to main (effective only with git>=2.28)'
git config --global init.defaultBranch main
echo Adjusting log aliases...
git config --global alias.lol "log --graph --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(bold white)— %an%C(reset)%C(bold yellow)%d%C(reset)' --abbrev-commit --date=relative"
#git config --global alias.lola "lol --all"  # SageMaker's git does not support alias chain :(
git config --global alias.lola "! git lol --all"
git config --global alias.lolc "! clear; git lol -\$(expr \`tput lines\` '*' 2 / 5)"
git config --global alias.lolac "! clear; git lol --all -\$(expr \`tput lines\` '*' 2 / 5)"
# Needed when notebook instance is not configured with a code repository.
echo Setup steps for HTTPS connections to AWS CodeCommit repositories
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true
if command -v delta &> /dev/null ; then
    echo "adjust-git.sh: delta is available..."
    git config --global core.pager "delta -s"
    git config --global interactive.diffFilter "delta -s --color-only"
    git config --global delta.navigate "true"
fi
git config pull.rebase false  # merge


echo "==============================================="
echo "  Env, Alias and Path ......"
echo "==============================================="
source ~/.bashrc
# check if a ENV KREW_ROOT exist
# if [ ! -z ${dry} ]; then # 变量有空格，检查失效
# if [ ! -z ${KREW_ROOT} ]; then # Shell 嵌套执行，检查也会失效
if ! grep -q "KREW_ROOT" $CUSTOM_BASH; then
  # Add alias if not set before
  cat >> $CUSTOM_BASH <<EOF

# Start adding by sm-nb-init

export HISTFILE=${CUSTOM_DIR}/bash_history # Persistent bash history
alias ..='source ~/.bashrc'
alias c=clear

alias a=aws
alias aid='aws sts get-caller-identity'

alias z='zip -r ../1.zip .'
alias g=git
alias jc=/bin/journalctl
alias s5='s5cmd'
alias 2s='cd /home/ec2-user/SageMaker'
alias 2c='cd /home/ec2-user/SageMaker/custom'
alias 2h='cd /home/ec2-user/SageMaker/efs/\${EFS_FS_NAME}/*hands'
alias 2l='cd /home/ec2-user/SageMaker/efs/\${EFS_FS_NAME}/*labs'
alias ncdu='ncdu --color dark'

alias l='ls -CF'
alias la='ls -A'
alias ls='ls --color=auto'
# alias ll='ls -alh --color=auto'
alias ll='ls -alhF --color=auto'

# Better dir color on dark terminal: changed from dark blue to lighter blue
export LS_COLORS="di=38;5;39"

man() {
    env \\
        LESS_TERMCAP_mb=\$(printf "\e[1;31m") \\
        LESS_TERMCAP_md=\$(printf "\e[1;31m") \\
        LESS_TERMCAP_me=\$(printf "\e[0m") \\
        LESS_TERMCAP_se=\$(printf "\e[0m") \\
        LESS_TERMCAP_so=\$(printf "\e[1;44;33m") \\
        LESS_TERMCAP_ue=\$(printf "\e[0m") \\
        LESS_TERMCAP_us=\$(printf "\e[1;32m") \\
        man "\$@"
}

export DSTAT_OPTS="-cdngym"
export TERM=xterm-256color
#export TERM=xterm-color


export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no"
# git_branch() {
#    local branch=\$(/usr/bin/git branch 2>/dev/null | grep '^*' | colrm 1 2)
#    [[ "\$branch" == "" ]] && echo "" || echo "(\$branch) "
# }

export dry="--dry-run=client -o yaml"
export KREW_ROOT="\$CUSTOM_DIR/bin/krew"
export PATH="\${KREW_ROOT:-\$HOME/.krew}/bin:\$PATH"

alias nlog=eks-log-collector.sh
#alias dfimage="docker run -v /var/run/docker.sock:/var/run/docker.sock --rm alpine/dfimage"
alias dfimage="docker run -v /var/run/docker.sock:/var/run/docker.sock --rm ghcr.io/laniksj/dfimage"

alias kk='kubectl-karpenter.sh'
alias kb='k8sgpt'
alias kt=kubetail
alias kgn='kubectl get nodes -L beta.kubernetes.io/arch -L karpenter.sh/capacity-type -L node.kubernetes.io/instance-type -L topology.kubernetes.io/zone -L karpenter.sh/nodepool'
alias kgp='kubectl get po -o wide'
alias kga='kubectl get all'
alias kgd='kubectl get deployment -o wide'
alias kgs='kubectl get svc -o wide'
alias ka='kubectl apply -f'
alias ke='kubectl explain'
alias kr='kubectl run \$dry'

alias tk='kt karpenter -n kube-system'
alias tlbc='kt aws-load-balancer-controller -n kube-system'
alias tebs='kt ebs-csi-controller -n kube-system'
alias tefs='kt efs-csi-controller -n kube-system'

alias egn='eksctl get nodegroup --cluster=\${EKS_CLUSTER_NAME}'
alias ess='eksctl scale nodegroup --cluster=\${EKS_CLUSTER_NAME} --name=system --nodes'
alias esn='eksctl scale nodegroup --cluster=\${EKS_CLUSTER_NAME} -n'
alias es0='eksctl scale nodegroup --cluster=\${EKS_CLUSTER_NAME} --nodes=0 --nodes-min=0 -n'

alias nsel=ec2-instance-selector

alias rr='sudo systemctl daemon-reload; sudo systemctl restart jupyter-server'

alias sshh='easy-ssh -c controller-machine \${HP_CLUSTER_NAME} '

export PIPX_HOME=~/SageMaker/custom/pipx
export PIPX_BIN_DIR=~/SageMaker/custom/bin

source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k

. <(eksctl completion bash)
alias e=eksctl
complete -F __start_eksctl e

# End adding by sm-nb-init

EOF
fi

# echo "" | sudo tee /etc/profile.d/initsmnb-cli.sh
# echo '' | sudo tee -a /etc/profile.d/initsmnb-cli.sh

if [ ! -f $CUSTOM_DIR/bin/b ]; then
  sudo bash -c "cat << EOF > /usr/local/bin/b
  #!/bin/bash
  /bin/bash
EOF"
  sudo chmod +x /usr/local/bin/b  
fi

echo " done"