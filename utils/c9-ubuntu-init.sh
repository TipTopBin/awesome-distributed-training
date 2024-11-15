#!/bin/bash

# set -e
mkdir -p ~/environment/do
mkdir -p ~/environment/efs
# mkdir -p ~/environment/system
mkdir -p ~/environment/scale
mkdir -p ~/environment/o11y
mkdir -p ~/environment/test
cd /tmp/
sudo apt-get update


echo "==============================================="
echo "  Install utilities ......"
echo "==============================================="
# 放在最前面，后续提取字段需要用到 jq
# moreutils: The command sponge allows us to read and write to the same file (cat a.txt|sponge a.txt)
# amazon-efs-utils
sudo apt install jq gettext bash-completion moreutils tree zsh xsel xclip wget git git-lfs build-essential net-tools libgl1 needrestart nfs-common  -y
sudo apt-get install -y software-properties-common apt-transport-https


# echo "==============================================="
# echo "  Update Bash to 5.2 ......"
# echo "==============================================="
# # wget https://ftp.gnu.org/gnu/bash/bash-5.2.15.tar.gz
# wget http://archive.ubuntu.com/ubuntu/pool/main/b/bash/bash_5.2.15-2ubuntu1.dsc http://archive.ubuntu.com/ubuntu/pool/main/b/bash/bash_5.2.15.orig.tar.gz http://archive.ubuntu.com/ubuntu/pool/main/b/bash/bash_5.2.15-2ubuntu1.debian.tar.xz
# dpkg-source -x bash_5.2.15-2ubuntu1.dsc
# cd bash-5.2.15
# # dpkg-checkbuilddeps
# ./configure
# make
# sudo make install
# chsh -s /bin/bash


echo "==============================================="
echo "  Install c9 to open files in cloud9 ......"
echo "==============================================="
npm install -g c9  # Install c9 to open files in cloud9 


echo "==============================================="
echo "  Upgrade awscli to v2 ......"
echo "==============================================="
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip /tmp/awscliv2.zip -d /tmp
# sudo /tmp/aws/install
sudo /tmp/aws/install --update
which aws_completer
echo $SHELL
cat >> ~/.bashrc <<EOF
complete -C '/usr/local/bin/aws_completer' aws
EOF
source ~/.bashrc
aws --version


echo "==============================================="
echo "  Install awscurl ......"
echo "==============================================="
# https://github.com/okigan/awscurl
cat >> ~/.bashrc <<EOF
export PATH=\$PATH:\$HOME/.local/bin:\$HOME/bin:/usr/local/bin
EOF
source ~/.bashrc
sudo python3 -m pip install awscurl


echo "==============================================="
echo "  Install kubectl ......"
echo "==============================================="
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
cat >> ~/.bashrc <<EOF
source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k
EOF
source ~/.bashrc
kubectl version --client --short
# get
echo "alias kgn='kubectl get nodes -L beta.kubernetes.io/arch -L karpenter.sh/capacity-type -L node.kubernetes.io/instance-type -L topology.kubernetes.io/zone -L karpenter.sh/provisioner-name'" | tee -a ~/.bashrc
echo "alias kgp='kubectl get po -o wide'" | tee -a ~/.bashrc
echo "alias kga='kubectl get all'" | tee -a ~/.bashrc
echo "alias kgd='kubectl get deployment -o wide'" | tee -a ~/.bashrc
echo "alias kgs='kubectl get svc -o wide'" | tee -a ~/.bashrc
echo "alias kdn='kubectl describe node'" | tee -a ~/.bashrc
echo "alias kdp='kubectl describe po'" | tee -a ~/.bashrc
echo "alias kdd='kubectl describe deployment'" | tee -a ~/.bashrc
echo "alias kds='kubectl describe svc'" | tee -a ~/.bashrc
# action
echo 'export dry="--dry-run=client -o yaml"' | tee -a ~/.bashrc
echo "alias ka='kubectl apply -f'" | tee -a ~/.bashrc
echo "alias kr='kubectl run $dry'" | tee -a ~/.bashrc
echo "alias ke='kubectl explain'" | tee -a ~/.bashrc
# tail logs
echo "alias tk='kt karpenter -n karpenter'" | tee -a ~/.bashrc # tail karpenter
echo "alias tlbc='kt aws-load-balancer-controller -n kube-system'" | tee -a ~/.bashrc # tail lbc
echo "alias tebs='kt ebs-csi-controller -n kube-system'" | tee -a ~/.bashrc # tail lbc
echo "alias tefs='kt efs-csi-controller -n kube-system'" | tee -a ~/.bashrc # tail lbc
source ~/.bashrc


echo "==============================================="
echo "  Install eksctl ......"
echo "==============================================="
ARCH=amd64 # for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz" 
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
sudo mv /tmp/eksctl /usr/local/bin
cat >> ~/.bashrc <<EOF
. <(eksctl completion bash)
alias e=eksctl
complete -F __start_eksctl e
EOF
echo "alias egn='eksctl get nodegroup --cluster=\${EKS_CLUSTER_NAME}'" | tee -a ~/.bashrc
echo "alias ess='eksctl scale nodegroup --cluster=\${EKS_CLUSTER_NAME} --name=system --nodes'" | tee -a ~/.bashrc # scale system node group 
echo "alias esn='eksctl scale nodegroup --cluster=\${EKS_CLUSTER_NAME} --name'" | tee -a ~/.bashrc # scale node group by name
eksctl info


echo "==============================================="
echo "  AWS do EKS: Manage EKS using the do-framework"
echo "==============================================="
git clone https://github.com/TipTopBin/aws-do-eks.git ~/environment/do/aws-do-eks
chmod +x ~/environment/do/aws-do-eks/utils/*.sh
chmod +x ~/environment/do/aws-do-eks/Container-Root/eks/ops/*.sh
cat >> ~/.bashrc <<EOF
export PATH="~/environment/do/aws-do-eks/utils:~/environment/do/aws-do-eks/Container-Root/eks/ops:\$PATH"
alias kk='kubectl-karpenter.sh'
alias l='ls -CF'
alias la='ls -A'
alias ll='ls -alh --color=auto'
alias ls='ls --color=auto'
alias nv='eks-node-viewer'
alias pe='pod-exec.sh'
EOF
source ~/.bashrc


echo "==============================================="
echo "  Kustomize ......"
echo "==============================================="
curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash
sudo mv -v kustomize /usr/local/bin
kustomize version


echo "==============================================="
echo "  Install krew ......"
echo "==============================================="
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)
cat >> ~/.bashrc <<EOF
export PATH="${KREW_ROOT:-\$HOME/.krew}/bin:\$PATH"
EOF
source ~/.bashrc
kubectl krew update
kubectl krew install ingress-nginx
kubectl ingress-nginx --help
kubectl krew install resource-capacity
kubectl krew install count
kubectl krew install get-all
kubectl krew install ktop
kubectl krew install ctx # kubectx
kubectl krew install ns # kubens
kubectl krew install nodepools # https://github.com/grafana/kubectl-nodepools
kubectl krew install colorize-applied
kubectl krew install bulk-action
kubectl krew list
kubectl plugin list


echo "==============================================="
echo "  Install helm ......"
echo "==============================================="
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm version
cat >> ~/.bashrc <<EOF
source <(helm completion bash)
alias h=helm
complete -F __start_helm h
EOF
source ~/.bashrc
helm repo add stable https://charts.helm.sh/stable
helm repo add eks https://aws.github.io/eks-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin


echo "==============================================="
echo "  Install k9s a Kubernetes CLI To Manage Your Clusters In Style ......"
echo "==============================================="
curl -sS https://webinstall.dev/k9s | bash
# check pod -> Shift + : and type pod and click Enter


echo "==============================================="
echo "  Config Go ......"
echo "==============================================="
go version
export GOPATH=$(go env GOPATH)
echo 'export GOPATH='${GOPATH} >> ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
source ~/.bashrc


echo "==============================================="
echo "  Install kubetail ......"
echo "==============================================="
curl -o /tmp/kubetail https://raw.githubusercontent.com/johanhaleby/kubetail/master/kubetail
chmod +x /tmp/kubetail
sudo mv /tmp/kubetail /usr/local/bin/kubetail
cat >> ~/.bashrc <<EOF
alias kt=kubetail
EOF
source ~/.bashrc


echo "==============================================="
echo "  Install ec2-instance-selector ......"
echo "==============================================="
# https://github.com/aws/amazon-ec2-instance-selector
curl -Lo ec2-instance-selector https://github.com/aws/amazon-ec2-instance-selector/releases/download/v2.4.1/ec2-instance-selector-`uname | tr '[:upper:]' '[:lower:]'`-amd64 && chmod +x ec2-instance-selector
chmod +x ./ec2-instance-selector
mkdir -p $HOME/bin && mv ./ec2-instance-selector $HOME/bin/ec2-instance-selector
cat >> ~/.bashrc <<EOF
alias nsel=ec2-instance-selector
EOF
source ~/.bashrc
nsel --version


echo "==============================================="
echo "  EKS Node Logs Collector (Linux) ......"
echo "==============================================="
# run this script on your eks node
sudo curl -o /usr/local/bin/nlog https://raw.githubusercontent.com/awslabs/amazon-eks-ami/master/log-collector-script/linux/eks-log-collector.sh
sudo chmod +x /usr/local/bin/nlog
nlog help


echo "==============================================="
echo "  Install eks-node-viewer ......"
echo "==============================================="
#https://github.com/awslabs/eks-node-viewer
go env -w GOPROXY=direct
go install github.com/awslabs/eks-node-viewer/cmd/eks-node-viewer@latest
export GOBIN=${GOBIN:-~/go/bin}
echo "export PATH=\$PATH:$GOBIN" >> ~/.bashrc
cat >> ~/.bashrc <<EOF
alias nfee='eks-node-viewer'
EOF
source ~/.bashrc
nfee -h


echo "==============================================="
echo " node-latency-for-k8s ......"
echo "==============================================="
# https://github.com/awslabs/node-latency-for-k8s
[[ `uname -m` == "aarch64" ]] && ARCH="arm64" || ARCH="amd64"
OS=`uname | tr '[:upper:]' '[:lower:]'`
wget https://github.com/awslabs/node-latency-for-k8s/releases/download/v0.1.10/node-latency-for-k8s_0.1.10_${OS}_${ARCH}.tar.gz -O /tmp/node-latency-for-k8s.tar.gz
sudo mkdir -p /opt/node-latency-for-k8s
sudo tar xzvf /tmp/node-latency-for-k8s.tar.gz -C /opt/node-latency-for-k8s
chmod +x /opt/node-latency-for-k8s/node-latency-for-k8s
cat >> ~/.bashrc <<EOF
export PATH="/opt/node-latency-for-k8s:\$PATH"
alias nlag='node-latency-for-k8s'
EOF
source ~/.bashrc
nlag -h


echo "==============================================="
echo "  Install yq for yaml processing ......"
echo "==============================================="
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq &&\
    sudo chmod +x /usr/bin/yq


echo "==============================================="
echo "  Install wildq ......"
echo "==============================================="
# wildq: Tool on-top of jq to manipulate INI files
sudo pip3 install wildq
# cat file.ini \
#   |wildq -i ini -M '.Key = "value"' \
#   |sponge file.ini


echo "==============================================="
echo "  Performance Test ......"
echo "==============================================="
sudo apt install siege fio ioping -y
siege -V
# vegeta https://github.com/tsenart/vegeta
curl -L "https://github.com/tsenart/vegeta/releases/download/v12.10.0/vegeta_12.10.0_linux_amd64.tar.gz" -o "/tmp/vegeta.tar.gz"
sudo tar xvzf /tmp/vegeta.tar.gz -C /usr/local/bin/
sudo chmod 755 /usr/local/bin/vegeta
vegeta -version


echo "==============================================="
echo "  Network Utilites ......"
echo "==============================================="
#https://repost.aws/knowledge-center/network-issue-vpc-onprem-ig
sudo apt install telnet mtr traceroute netcat -y
pip3 install httpie


echo "==============================================="
echo "  Cofing dfimage ......"
echo "==============================================="
cat >> ~/.bashrc <<EOF
alias dfimage="docker run -v /var/run/docker.sock:/var/run/docker.sock --rm alpine/dfimage"  
EOF
source ~/.bashrc
# dfimage -sV=1.36 nginx:latest 


echo "==============================================="
echo " dos2unix ......"
echo "==============================================="
sudo apt install dos2unix -y
# dos2unix xxx.sh


echo "==============================================="
echo " S3 Mountpoint ......"
echo "==============================================="
wget https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.deb -O /tmp/mount-s3.deb
sudo apt-get install -y /tmp/mount-s3.deb
echo "alias ms3='mount-s3'" | tee -a ~/.bashrc
# mount-s3 [OPTIONS] <BUCKET_NAME> <DIRECTORY>


echo "==============================================="
echo " s5cmd ......"
echo "==============================================="
#https://github.com/peak/s5cmd
export S5CMD_URL=$(curl -s https://api.github.com/repos/peak/s5cmd/releases/latest \
| grep "browser_download_url.*_Linux-64bit.tar.gz" \
| cut -d : -f 2,3 \
| tr -d \")
# echo $S5CMD_URL
wget $S5CMD_URL -O /tmp/s5cmd.tar.gz
sudo mkdir -p /opt/s5cmd/
sudo tar xzvf /tmp/s5cmd.tar.gz -C /opt/s5cmd
cat >> ~/.bashrc <<EOF
export PATH="/opt/s5cmd:\$PATH"
EOF
source ~/.bashrc
s5cmd version
echo "alias s5='s5cmd'" | tee -a ~/.bashrc


echo "==============================================="
echo " Ask bedrock ......"
echo "==============================================="
pip install ask-bedrock
echo "alias abc='ask-bedrock converse'" | tee -a ~/.bashrc
# ask-bedrock converse
# ask-bedrock configure


echo "==============================================="
echo " k8sgpt ......"
echo "==============================================="
curl -LO https://github.com/k8sgpt-ai/k8sgpt/releases/download/v0.3.21/k8sgpt_amd64.deb
sudo dpkg -i k8sgpt_amd64.deb
echo "alias kb='k8sgpt'" | tee -a ~/.bashrc
# k8sgpt auth add --backend amazonbedrock --model anthropic.claude-v2
# k8sgpt auth list
# k8sgpt auth default -p amazonbedrock
# k8sgpt analyze -e -b amazonbedrock
# export AWS_ACCESS_KEY=
# export AWS_SECRET_ACCESS_KEY=
# export AWS_DEFAULT_REGION=


echo "==============================================="
echo " A Data Migration Tool (abbr. ADMT) ......"
echo "==============================================="
# https://github.com/TipTopBin/data-migration-tool-for-s3


echo "==============================================="
echo "  Update root PATH ......"
echo "==============================================="
echo "export PATH=\$PATH:\$HOME/.local/bin:\$HOME/bin:/usr/local/bin" | sudo tee -a /root/.bashrc


echo "==============================================="
echo "  More Aliases ......"
echo "==============================================="
cat > ~/.vimrc <<EOF
set number
set expandtab
set tabstop=2
set shiftwidth=2
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab
EOF
# .bashrc
cat >> ~/.bashrc <<EOF
alias c=clear
alias z='zip -r ../1.zip .'
alias ll='ls -alh --color=auto'
alias sc=/bin/systemctl
alias jc=/bin/journalctl
export TERM=xterm-256color
#export TERM=xterm-color
alias 2e='cd ~/environment'
EOF
source ~/.bashrc
# journalctl -u kubelet | grep error 
# 最后再执行一次 source
sudo mount -a
echo "source .bashrc"
shopt -s expand_aliases
. ~/.bashrc