#!/bin/bash

source ~/.bashrc

# Detect environment and set appropriate paths
if [[ -d "/home/ec2-user/SageMaker" ]]; then
  # SageMaker environment
  PROJECT_ROOT=${PROJECT_ROOT:-${JUPYTER_SERVER_ROOT:-"/home/ec2-user/SageMaker"}}
elif [[ -d "$HOME/environment" ]]; then
  # Cloud9 environment
  PROJECT_ROOT=${PROJECT_ROOT:-${JUPYTER_SERVER_ROOT:-"$HOME/environment"}}
else
  # Default fallback
  PROJECT_ROOT=${PROJECT_ROOT:-${JUPYTER_SERVER_ROOT:-"$HOME"}}
fi

CUSTOM_DIR="$PROJECT_ROOT/custom"
CUSTOM_BASH="$CUSTOM_DIR/bashrc"

#===Style Definitions===
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print a yellow header
print_header() {
    echo -e "\n${BLUE}=================================================${NC}"
    echo -e "\n${YELLOW}==== $1 ====${NC}\n"
    echo -e "\n${BLUE}=================================================${NC}"
}

print_header "🚀 Welcome to the Initialization Script! 🚀"

mkdir -p "$CUSTOM_DIR"/bin && \
  mkdir -p "$CUSTOM_DIR"/docker && \
  mkdir -p "$CUSTOM_DIR"/envs && \
  mkdir -p "$CUSTOM_DIR"/vscode && \
  mkdir -p "$CUSTOM_DIR"/tmp && \
  mkdir -p "$CUSTOM_DIR"/logs

if ! grep -q "CUSTOM_BASH" $CUSTOM_BASH; then
  echo "Set custom dir and bashrc"
  sudo chmod 777 "$CUSTOM_DIR"/tmp

  echo "export CUSTOM_DIR=${CUSTOM_DIR}" >> $CUSTOM_BASH
  echo "export CUSTOM_BASH=${CUSTOM_BASH}" >> $CUSTOM_BASH
  echo "export PIPX_HOME=$CUSTOM_DIR/pipx" >> $CUSTOM_BASH
  echo "export PIPX_BIN_DIR=$CUSTOM_DIR/bin" >> $CUSTOM_BASH

  echo 'export PATH=$PATH:$CUSTOM_DIR/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin' >> $CUSTOM_BASH
fi


print_header "Load custom bashrc and ssh ......"
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

cat ~/.bashrc.ori >> ~/.bashrc # Add back original .bashrc content

# Add custom bash file if not set before
cat >> ~/.bashrc <<EOF

bashrc_files=(bashrc)
path="$CUSTOM_DIR/"
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
ln -s $CUSTOM_DIR/vscode ~/.vscode-server 2>/dev/null || true

source ~/.bashrc

# check if a ENV MY_AZ exist
if ! grep -q "MY_AZ" $CUSTOM_BASH; then
  echo "Add envs: ACCOUNT_ID AWS_REGION MY_AZ"

  MY_AZ=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
  if [[ $MY_AZ == "" ]]; then
    # IMDSv2
    IMDS_TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
    MY_AZ=`curl -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
  fi

  cat >> $CUSTOM_BASH <<EOF  

export AWS_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export MY_AZ=${MY_AZ}
FLAVOR="$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f 2)"

EOF
fi

source ~/.bashrc

test -n "$AWS_REGION" && echo AWS_REGION is "$AWS_REGION" || echo AWS_REGION is not set
aws configure set default.region ${AWS_REGION}
aws configure get default.region
aws configure set region $AWS_REGION
aws configure set default.s3.preferred_transfer_client crt


# SSH 放在脚本靠前位置，方便调试
if [ -f $CUSTOM_DIR/private_key.pem ]
then
  echo "Setup SSH Keys"
  sudo cp $CUSTOM_DIR/private_key.pem ~/.ssh/id_rsa
  sudo cp $CUSTOM_DIR/public_key.pem ~/.ssh/id_rsa.pub
  sudo chmod 400 ~/.ssh/id_rsa
  
  # Try to set owner based on username
  CURR_USER=$(whoami)
  sudo chown -R $CURR_USER:$CURR_USER ~/.ssh/ 2>/dev/null || sudo chown -R ec2-user:ec2-user ~/.ssh/ 2>/dev/null || true
  
  # 免密登录
  {
  cat ~/.ssh/id_rsa.pub|tr '\n' ' '
  } >> ~/.ssh/authorized_keys

  # SSH Forward - only if needed
  if [ "$CURR_USER" != "ubuntu" ] && id ubuntu &>/dev/null; then
    sudo mkdir -p /home/ubuntu/.ssh
    sudo cp ~/.ssh/* /home/ubuntu/.ssh/ 2>/dev/null || true
    sudo chown -R ubuntu:ubuntu /home/ubuntu/ 2>/dev/null || true
  fi
fi

# sagemaker-hyperpod ssh
# https://catalog.workshops.aws/sagemaker-hyperpod/en-US/01-cluster/05-ssh
if [ ! -f $CUSTOM_DIR/bin/easy-ssh ]; then
  wget -O $CUSTOM_DIR/bin/easy-ssh https://raw.githubusercontent.com/TipTopBin/awesome-distributed-training/main/1.architectures/5.sagemaker-hyperpod/easy-ssh.sh
  chmod +x $CUSTOM_DIR/bin/easy-ssh
fi


echo "==============================================="
echo "  Performance config ......"
echo "==============================================="
sudo bash -c 'cat >> /etc/sysctl.conf' << EOF
fs.inotify.max_user_watches=520088
EOF
sudo sysctl -p
cat /proc/sys/fs/inotify/max_user_watches

# yum
sudo yum-config-manager --disable centos-extras 2>/dev/null || true
grep '^max_connections=' /etc/yum.conf &> /dev/null || echo "max_connections=10" | sudo tee -a /etc/yum.conf


echo "==============================================="
echo "  Utilities ......"
echo "==============================================="
# moreutils: The command sponge allows us to read and write to the same file (cat a.txt|sponge a.txt)
sudo amazon-linux-extras install epel -y 2>/dev/null || true
sudo yum-config-manager --add-repo=https://copr.fedorainfracloud.org/coprs/cyqsimon/el-rust-pkgs/repo/epel-7/cyqsimon-el-rust-pkgs-epel-7.repo 2>/dev/null || true
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
  unzip -o $CUSTOM_DIR/bin/awscliv2.zip -d $CUSTOM_DIR/bin
fi
sudo $CUSTOM_DIR/bin/aws/install --update
rm -f $HOME/anaconda3/envs/JupyterSystemEnv/bin/aws 2>/dev/null || true
sudo mv $HOME/anaconda3/bin/aws $HOME/anaconda3/bin/aws1 2>/dev/null || true
ls -l /usr/local/bin/aws
source ~/.bashrc
aws --version

aws configure set default.region ${AWS_REGION}
aws configure get default.region
aws configure set region $AWS_REGION
# refer from aws-samples hpc repo
aws configure set default.s3.max_concurrent_requests 100
aws configure set default.s3.max_queue_size 10000
aws configure set default.s3.multipart_threshold 64MB
aws configure set default.s3.multipart_chunksize 16MB


# Install session-manager
if [ ! -f $CUSTOM_DIR/bin/session-manager-plugin.rpm ]; then
  curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "$CUSTOM_DIR/bin/session-manager-plugin.rpm"
fi
sudo yum install -y $CUSTOM_DIR/bin/session-manager-plugin.rpm
session-manager-plugin

# ec2-instance-selector
if [ ! -f $CUSTOM_DIR/bin/ec2-instance-selector ]; then
  target=$(uname | tr '[:upper:]' '[:lower:]')-amd64
  LATEST_DOWNLOAD_URL=$(curl --silent "https://api.github.com/repos/aws/amazon-ec2-instance-selector/releases/latest" | grep "\"browser_download_url\": \"https.*$target.tar.gz" | sed -E 's/.*"([^"]+)".*/\1/')
  curl -Lo $CUSTOM_DIR/bin/ec2-instance-selector.tar.gz $LATEST_DOWNLOAD_URL
  tar -xvf $CUSTOM_DIR/bin/ec2-instance-selector.tar.gz -C $CUSTOM_DIR/bin
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


# https://github.com/muesli/duf
echo "Setup duf"
if [ ! -f $CUSTOM_DIR/bin/duf.rpm ]; then
    DOWNLOAD_URL="https://github.com/muesli/duf/releases/download/v0.8.1/duf_0.8.1_linux_amd64.rpm"
    wget $DOWNLOAD_URL -O $CUSTOM_DIR/bin/duf.rpm
fi
sudo yum localinstall -y $CUSTOM_DIR/bin/duf.rpm


if [ ! -f $CUSTOM_DIR/go/bin/go ]; then
  echo "  Install Go ......"
  wget https://go.dev/dl/go1.23.3.linux-amd64.tar.gz -O /tmp/go.tar.gz
  sudo tar xzvf /tmp/go.tar.gz -C $CUSTOM_DIR
  cat >> $CUSTOM_BASH <<EOF
export PATH="$CUSTOM_DIR/go/bin:\$PATH"
EOF
fi

# uv
curl -LsSf https://astral.sh/uv/install.sh | sh


echo "==============================================="
echo "  Container tools ......"
echo "==============================================="
ARCH=amd64 # for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
PLATFORM=$(uname -s)_$ARCH
if [ ! -f $CUSTOM_DIR/bin/eksctl_$PLATFORM.tar.gz ]; then
  curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz" -o $CUSTOM_DIR/bin/eksctl_$PLATFORM.tar.gz
  tar -xzf $CUSTOM_DIR/bin/eksctl_$PLATFORM.tar.gz -C $CUSTOM_DIR/bin
fi

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


# k8sgpt
if [ ! -f $CUSTOM_DIR/bin/k8sgpt_Linux_x86_64.tar.gz ]; then
  wget -O $CUSTOM_DIR/bin/k8sgpt_Linux_x86_64.tar.gz https://github.com/k8sgpt-ai/k8sgpt/releases/download/v0.3.25/k8sgpt_Linux_x86_64.tar.gz
  tar -xvf $CUSTOM_DIR/bin/k8sgpt_Linux_x86_64.tar.gz -C $CUSTOM_DIR/bin
fi

# docker
if [ -f /etc/yum.repos.d/docker-ce.repo ]; then  
  sudo rm /etc/yum.repos.d/docker-ce.repo || true # Lots of problem, from wrong .repo content to broken selinux-container
fi

if [ -f /usr/lib/systemd/system/docker.service ]; then
  # tmp dir
  # Give docker build a bit more space. E.g., as of Nov'21, building a custom
  # image based on the pytorch-1.10 DLC would fail due to exhausted /tmp.
  sudo sed -i \
      's|^\[Service\]$|[Service]\nEnvironment="DOCKER_TMPDIR=$CUSTOM_DIR/tmp"|' \
      /usr/lib/systemd/system/docker.service

  # change docker data root if docker daemon.json exists
  if [ -f /etc/docker/daemon.json ]; then
    PYTHON_BIN=$(which python || which python3)
    sudo $PYTHON_BIN -c "
import json

with open('/etc/docker/daemon.json') as f:
    d = json.load(f)

d['data-root'] = '$CUSTOM_DIR/docker'

with open('/etc/docker/daemon.json', 'w') as f:
    json.dump(d, f, indent=4)
    f.write('\n')
"
  fi

  # https://docs.aws.amazon.com/sagemaker/latest/dg/docker-containers-troubleshooting.html
  mkdir -p ~/.sagemaker
  cat > ~/.sagemaker/config.yaml <<EOF
local:
  container_root: $CUSTOM_DIR/tmp
EOF
  # restart docker
  sudo systemctl daemon-reload
  sudo systemctl restart docker
  sudo systemctl show --property=Environment docker
fi

# Docker Compose
if [ -f "$HOME/anaconda3/bin/docker-compose" ]; then
  mkdir -p ~/.local/bin
  ln -s "$HOME/anaconda3/bin/docker-compose" ~/.local/bin/ 2>/dev/null || true
fi


echo "==============================================="
echo "  GenAI tools ......"
echo "==============================================="
# q developer cli
if [ ! -f $CUSTOM_DIR/bin/q.zip ]; then
  curl --proto '=https' --tlsv1.2 -sSf "https://desktop-release.codewhisperer.us-east-1.amazonaws.com/latest/q-x86_64-linux.zip" -o "$CUSTOM_DIR/bin/q.zip"
  unzip -o $CUSTOM_DIR/bin/q.zip -d $CUSTOM_DIR/bin
  # codecatalyst.aws
  # $CUSTOM_DIR/bin/q/install.sh
fi


echo "==============================================="
echo "  Load custom config ......"
echo "==============================================="
# EKS
if [ ! -z "$EKS_CLUSTER_NAME" ]; then
    /usr/local/bin/aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}
fi


# S3 bucket
if [ ! -z "$S3_INTG_AUTO" ]; then
    mkdir -p "$PROJECT_ROOT/s3/${S3_INTG_AUTO}"
    mount-s3 ${S3_INTG_AUTO} "$PROJECT_ROOT/s3/${S3_INTG_AUTO}" --allow-delete --dir-mode 777
fi


# EFS
if [ ! -z "$EFS_FS_ID" ]; then
  mkdir -p "$PROJECT_ROOT/efs/${EFS_FS_NAME}"
  echo "${EFS_FS_ID}.efs.${AWS_REGION}.amazonaws.com:/ $PROJECT_ROOT/efs/${EFS_FS_NAME} nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" | sudo tee -a /etc/fstab # NFS
  sudo mount -a
fi


# Instance store
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
sudo chown -hR +1000:+1000 /opt/dlami/* 2>/dev/null || true


# Git
if [ ! -z "$GIT_USER" ]; then
  echo "setup git user"
  git config --global user.name ${GIT_USER}
  git config --global user.email ${GIT_MAIL}  
fi
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
git config --global alias.lola "! git lol --all"
git config --global alias.lolc "! clear; git lol -\$(expr \`tput lines\` '*' 2 / 5)"
git config --global alias.lolac "! clear; git lol --all -\$(expr \`tput lines\` '*' 2 / 5)"
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
if ! grep -q "KREW_ROOT" $CUSTOM_BASH; then
  # Add alias if not set before
  cat >> $CUSTOM_BASH <<EOF

# Start adding by al2023-init
export PROJECT_ROOT=$PROJECT_ROOT
export HISTFILE=${CUSTOM_DIR}/bash_history # Persistent bash history
alias ..='source ~/.bashrc'
alias c=clear
alias a=aws
alias aid='aws sts get-caller-identity'
alias z='zip -r ../1.zip .'
alias g=git
alias jc=/bin/journalctl
alias s5='s5cmd'
alias 2c='cd $CUSTOM_DIR'
alias l='ls -CF'
alias la='ls -A'
alias ls='ls --color=auto'
alias ll='ls -alhF --color=auto'
alias ncdu='ncdu --color dark'
export LS_COLORS="di=38;5;39" # Better dir color on dark terminal: changed from dark blue to lighter blue

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

export PROJECT_ROOT=$PROJECT_ROOT
export DSTAT_OPTS="-cdngym"
export TERM=xterm-256color
export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no"
export KREW_ROOT="\$CUSTOM_DIR/bin/krew"
alias nlog=eks-log-collector.sh
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
export dry="--dry-run=client -o yaml"
alias kr='kubectl run \$dry'
alias tk='kt karpenter -n kube-system'
alias tlbc='kt aws-load-balancer-controller -n kube-system'
alias tebs='kt ebs-csi-controller -n kube-system'
alias tefs='kt efs-csi-controller -n kube-system'
alias nsel=ec2-instance-selector
alias rr='sudo systemctl daemon-reload; sudo systemctl restart jupyter-server'
alias sshh='easy-ssh -c controller-machine \${HP_CLUSTER_NAME} '
export PATH="\${KREW_ROOT:-\$HOME/.krew}/bin:\$PATH"
export PIPX_HOME=$CUSTOM_DIR/pipx
export PIPX_BIN_DIR=$CUSTOM_DIR/bin

source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k

. <(eksctl completion bash)
alias e=eksctl
complete -F __start_eksctl e

# End adding by al2023-init

EOF
fi

echo " done"
