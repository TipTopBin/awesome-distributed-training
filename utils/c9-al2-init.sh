#!/bin/bash

# set -e

download_and_verify () {
  url=$1
  checksum=$2
  out_file=$3

  curl --location --show-error --silent --output $out_file $url

  echo "$checksum $out_file" > "$out_file.sha256"
  sha256sum --check "$out_file.sha256"
  
  rm "$out_file.sha256"
}

mkdir -p ~/environment/do
# mkdir -p ~/environment/system
mkdir -p ~/environment/efs
mkdir -p ~/environment/scale
mkdir -p ~/environment/o11y
mkdir -p ~/environment/test
cd /tmp/


echo "==============================================="
echo "  Config yum ......"
echo "==============================================="
# reset yum history
sudo yum history new
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo


echo "==============================================="
echo "  Install jq, envsubst (from GNU gettext utilities) and bash-completion ......"
echo "==============================================="
# 放在最前面，后续提取字段需要用到 jq
# moreutils: The command sponge allows us to read and write to the same file (cat a.txt|sponge a.txt)
sudo yum -y install jq gettext bash-completion moreutils tree zsh xsel xclip amazon-efs-utils


echo "==============================================="
echo "  Install c9 to open files in cloud9 ......"
echo "==============================================="
npm install -g c9  # Install c9 to open files in cloud9 
# aws cloud9 update-environment --environment-id $C9_PID --managed-credentials-action DISABLE
# rm -vf ${HOME}/.aws/credentials
# example  c9 open ~/package.json


echo "==============================================="
echo "  Upgrade awscli to v2 ......"
echo "==============================================="
sudo mv /bin/aws /bin/aws1
sudo mv ~/anaconda3/bin/aws ~/anaconda3/bin/aws1
# ls -l /usr/local/bin/aws
# rm -fr awscliv2.zip aws
rm -rf /usr/local/bin/aws 2> /dev/null
rm -rf /usr/local/aws-cli 2> /dev/null
rm -rf aws awscliv2.zip 2> /dev/null
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install
# sudo ./aws/install --update
which aws_completer
echo $SHELL
cat >> ~/.bashrc <<EOF
complete -C '/usr/local/bin/aws_completer' aws
EOF
source ~/.bashrc
aws --version
# container way
# https://aws.amazon.com/blogs/developer/new-aws-cli-v2-docker-images-available-on-amazon-ecr-public/
# https://github.com/richarvey/aws-docker-toolkit
# docker run --rm -it public.ecr.aws/aws-cli/aws-cli:2.9.1 --version aws-cli/2.9.1 Python/3.9.11 Linux/5.10.47-linuxkit docker/aarch64.amzn.2 prompt/off
# Mac
# curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "/tmp/AWSCLIV2.pkg"
# sudo installer -pkg /tmp/AWSCLIV2.pkg -target /
# which aws
# aws --version
# rm -fr /tmp/AWSCLIV2.pkg


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
echo "  Install eksctl ......"
echo "==============================================="
# curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
ARCH=amd64 # for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz" 
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
sudo mv /tmp/eksctl /usr/local/bin
# eksctl version
eksctl info
# 配置自动完成 eksctl bash-completion
cat >> ~/.bashrc <<EOF
. <(eksctl completion bash)
alias e=eksctl
complete -F __start_eksctl e
EOF
# eksctl completion bash >> ~/.bash_completion
# . /etc/profile.d/bash_completion.sh
# . ~/.bash_completion
echo "alias egn='eksctl get nodegroup --cluster=\${EKS_CLUSTER_NAME}'" | tee -a ~/.bashrc
# scale system node group 
echo "alias ess='eksctl scale nodegroup --cluster=\${EKS_CLUSTER_NAME} --name=system --nodes'" | tee -a ~/.bashrc
# scale node group by name
echo "alias esn='eksctl scale nodegroup --cluster=\${EKS_CLUSTER_NAME} --name'" | tee -a ~/.bashrc


echo "==============================================="
echo "  Install kubectl ......"
echo "==============================================="
# 安装 kubectl 并配置自动完成
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
cat >> ~/.bashrc <<EOF
source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k
EOF
source ~/.bashrc
kubectl version --client --short
# Enable some kubernetes aliases
# echo "alias kgn='kubectl get nodes -L beta.kubernetes.io/arch -L eks.amazonaws.com/capacityType -L node.kubernetes.io/instance-type -L eks.amazonaws.com/nodegroup -L topology.kubernetes.io/zone'" | tee -a ~/.bashrc
# echo "alias kk='kubectl get nodes -L beta.kubernetes.io/arch -L eks.amazonaws.com/capacityType -L karpenter.sh/capacity-type -L node.kubernetes.io/instance-type -L topology.kubernetes.io/zone -L karpenter.sh/provisioner-name'" | tee -a ~/.bashrc
echo "alias kgn='kubectl get nodes -L beta.kubernetes.io/arch -L karpenter.sh/capacity-type -L node.kubernetes.io/instance-type -L topology.kubernetes.io/zone -L karpenter.sh/provisioner-name'" | tee -a ~/.bashrc
# https://jqlang.github.io/jq/manual/#basic-filters
# export KUBECTL_KARPENTER="eval \"\$(kubectl get nodes -o json | jq '.items|=sort_by(.metadata.creationTimestamp) | .items[]' | jq -r '[ \"printf\", \"%-50s %-19s %-19s %-1s %-2s %-6s %-15s %s %s %s\\n\", .metadata.name, (.spec.providerID | split(\"/\")[4]), (.metadata.creationTimestamp | sub(\"Z\";\"\")), (if ((.status.conditions | map(select(.status == \"True\"))[0].type) == \"Ready\") then \"✔\" else \"?\" end), (.metadata.labels.\"topology.kubernetes.io/zone\" | split(\"-\")[2]), (.metadata.labels.\"node.kubernetes.io/instance-type\" | sub(\"arge\";\"\")), (if .metadata.labels.\"karpenter.k8s.aws/instance-network-bandwidth\" then .metadata.labels.\"karpenter.k8s.aws/instance-cpu\"+\"核\"+(.metadata.labels.\"karpenter.k8s.aws/instance-memory\" | tonumber/1024 | tostring+\"G\")+(.metadata.labels.\"karpenter.k8s.aws/instance-network-bandwidth\" | tonumber/1000 | tostring+\"Gbps\") else .status.capacity.cpu+\"核\"+(.status.capacity.memory | sub(\"Ki\";\"\") | tonumber/1024/1024 | floor+1 | tostring+\"G\")+\"\" end), (.metadata.labels.\"beta.kubernetes.io/arch\" | sub(\"64\";\"\") | sub(\"amd\";\"x86\")), (if .metadata.labels.\"karpenter.sh/capacity-type\" == \"on-demand\" or .metadata.labels.\"eks.amazonaws.com/capacityType\" == \"ON_DEMAND\" then \"按需\" else \"SPOT\" end), (.metadata.labels.\"karpenter.sh/provisioner-name\" // \" *节点组*\") ] | @sh')\""
# echo ${KUBECTL_KARPENTER} > kk && chmod +x kk
# sudo mv -v kk /usr/bin
echo "alias kgp='kubectl get po -o wide'" | tee -a ~/.bashrc
# sort -k 8 to sort by the NODE column
# kgp | sort -k 8
echo "alias kga='kubectl get all'" | tee -a ~/.bashrc
echo "alias kgd='kubectl get deployment -o wide'" | tee -a ~/.bashrc
echo "alias kgs='kubectl get svc -o wide'" | tee -a ~/.bashrc
echo "alias kdn='kubectl describe node'" | tee -a ~/.bashrc
echo "alias kdp='kubectl describe po'" | tee -a ~/.bashrc
echo "alias kdd='kubectl describe deployment'" | tee -a ~/.bashrc
echo "alias kds='kubectl describe svc'" | tee -a ~/.bashrc
echo 'export dry="--dry-run=client -o yaml"' | tee -a ~/.bashrc
echo "alias ka='kubectl apply -f'" | tee -a ~/.bashrc
echo "alias kr='kubectl run $dry'" | tee -a ~/.bashrc
echo "alias ke='kubectl explain'" | tee -a ~/.bashrc
# kubectl explain pod.spec | head
# kubectl explain pod.spec | grep required -A 3
# kubectl explain pod.spec.containers | grep required- -A 2 
echo "alias pk='k patch configmap config-logging -n karpenter --patch'" | tee -a ~/.bashrc
# tail logs
echo "alias tk='kt karpenter -n karpenter'" | tee -a ~/.bashrc # tail karpenter
echo "alias tlbc='kt aws-load-balancer-controller -n kube-system'" | tee -a ~/.bashrc # tail lbc
echo "alias tebs='kt ebs-csi-controller -n kube-system'" | tee -a ~/.bashrc # tail lbc
echo "alias tefs='kt efs-csi-controller -n kube-system'" | tee -a ~/.bashrc # tail lbc
# k patch configmap config-logging -n karpenter --patch 
# pk '{"data":{"loglevel.controller":"info"}}'
# k get po -l app.kubernetes.io/name=aws-node -n kube-system -o wide
source ~/.bashrc
# https://kubernetes.io/docs/reference/kubectl/jsonpath/
# JSONPATH='{range .items[*]} {@.metadata.name}{"\t"} {@.spec.providerID}) {"\n"}{end}'
# k get no -o jsonpath="${JSONPATH}"
# 强制删除
# kubectl get node -o name node-name | xargs -i kubectl patch {} -p '{"metadata":{"finalizers":[]}}' --type=merge
# Get a list of just the kubectl config subcommands
# kubectl config --help
# kubectl config 2>&1 | grep "Available Commands" -A 15
# Get a collated list of the kinds of objects which are namespaced and which are not
#kubectl api-resources | awk 'BEGIN{ns="";nonns=""};/true/{ns=ns FS $1};/false/{nonns=nonns FS $1};END{print "namespaced: " ns; print ""; print "non-namespaced:" nonns}'
# force delete
# TO_REMOVE_NS=kubesphere-monitoring-system
# kubectl get namespace "${TO_REMOVE_NS}" -o json \
#   | tr -d "\n" | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/" \
#   | kubectl replace --raw /api/v1/namespaces/${TO_REMOVE_NS}/finalize -f -
# watch -n 10 kubectl get pods --all-namespaces


echo "==============================================="
echo "  AWS do EKS: Manage EKS using the do-framework"
echo "==============================================="
git clone https://github.com/CLOUDCNTOP/aws-do-eks.git ~/environment/do/aws-do-eks
chmod +x ~/environment/do/aws-do-eks/utils/*.sh
chmod +x ~/environment/do/aws-do-eks/Container-Root/eks/ops/*.sh
cat >> ~/.bashrc <<EOF
export PATH="~/environment/do/aws-do-eks/utils:~/environment/do/aws-do-eks/Container-Root/eks/ops:$PATH"
alias kk='kubectl-karpenter.sh'
#alias kdp='pod-describe.sh'
alias kln='nodes-list.sh'
#alias kln='nodes-types-list.sh'
alias klp='pods-list.sh'
alias kl='pod-logs.sh'
alias l='ls -CF'
alias la='ls -A'
alias ll='ls -alh --color=auto'
alias lp='pods-list.sh'
alias ls='ls --color=auto'
alias nv='eks-node-viewer'
alias pe='pod-exec.sh'
alias pl='pod-logs.sh'
alias tx='torchx'
alias wn='watch-nodes.sh'
#alias wn='watch-node-types.sh'
alias wp='watch-pods.sh'
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
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
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
kubectl nodepools list
# kubectl krew install lineage
#kubectl krew install custom-cols
#kubectl krew install explore
#kubectl krew install flame
#kubectl krew install foreach
#kubectl krew install fuzzy
#kubectl krew index add kvaps https://github.com/kvaps/krew-index
#kubectl krew install kvaps/node-shell
kubectl krew list
# k resource-capacity --util --sort cpu.util # 查看节点
# k resource-capacity --pods --util --pod-labels app.kubernetes.io/name=aws-node --namespace kube-system --sort cpu.util
# k get po -l app.kubernetes.io/name=aws-node -n kube-system -o wide
kubectl resource-capacity -n kube-system -p -c
# kubectl ktop
# kubectl ktop -n default
# kubectl lineage --version
# k get-all
# k count pod
# k node-shell <node>
kubectl plugin list
# git clone https://github.com/surajincloud/kubectl-eks.git
# cd kubectl-eks
# make
# sudo mv ./kubectl-eks /usr/local/bin
# cd ..
# kubectl krew index add surajincloud git@github.com:surajincloud/krew-index.git
# kubectl krew search eks
# kubectl krew install surajincloud/kubectl-eks
# https://surajincloud.github.io/kubectl-eks/usage/
# kubectl eks irsa
# kubectl eks irsa -n kube-system
# kubectl eks ssm <name-of-the-node>
# kubectl eks nodes
# kubectl eks suggest-ami
# sudo required
# Install kubens, kubectx - sudo required
# sudo -s
# git clone https://github.com/ahmetb/kubectx /opt/kubectx
# ln -s /opt/kubectx/kubens /usr/local/bin/kubens
# ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
# exit


echo "==============================================="
echo "  Install helm ......"
echo "==============================================="
# https://helm.sh/docs/helm/helm_completion_bash/
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm version
helm repo add stable https://charts.helm.sh/stable
# helm completion bash | sudo tee /etc/bash_completion.d/helm
cat >> ~/.bashrc <<EOF
source <(helm completion bash)
alias h=helm
complete -F __start_helm h
EOF
source ~/.bashrc
# helm completion bash >> ~/.bash_completion
# . /etc/profile.d/bash_completion.sh
# . ~/.bash_completion
# source <(helm completion bash)


echo "==============================================="
echo "  Install k9s a Kubernetes CLI To Manage Your Clusters In Style ......"
echo "==============================================="
# 参考 https://segmentfault.com/a/1190000039755239
curl -sS https://webinstall.dev/k9s | bash
# check pod -> Shift + : and type pod and click Enter


echo "==============================================="
echo "  K10 ......"
echo "==============================================="
# https://docs.kasten.io/latest/install/aws/aws.html


echo "==============================================="
echo "  Config Go ......"
echo "==============================================="
go version
export GOPATH=$(go env GOPATH)
echo 'export GOPATH='${GOPATH} >> ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
source ~/.bashrc


# echo "==============================================="
# echo "  Install ccat ......"
# echo "==============================================="
# go install github.com/owenthereal/ccat@latest


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
# nsel --efa-support --gpu-memory-total-min 80 -r us-west-2 -o table-wide
# aws ec2 describe-instance-types --filters Name=network-info.efa-supported,Values=true --query "InstanceTypes[*].[InstanceType]" --output text | sort
# nsel --efa-support --gpus 0 -r us-west-2 -o table-wide
# nsel --base-instance-type m7i-flex.xlarge -o table-wide
# ec2-instance-selector --memory 4 --vcpus 2 --cpu-architecture x86_64 -r us-east-1
# ec2-instance-selector --network-performance 100 --usage-class spot -r us-east-1
# ec2-instance-selector --memory 4 --vcpus 2 --cpu-architecture x86_64 -r us-east-1 -o table
# ec2-instance-selector -r us-east-1 -o table-wide --max-results 10 --sort-by memory --sort-direction asc
# ec2-instance-selector -r us-east-1 -o table-wide --max-results 10 --sort-by .MemoryInfo.SizeInMiB --sort-direction desc
# ec2-instance-selector --max-results 1 -v
# ec2-instance-selector -o interactive


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
export PATH="/opt/node-latency-for-k8s:$PATH"
alias nlag='node-latency-for-k8s'
EOF
source ~/.bashrc
nlag -h


echo "==============================================="
echo "  EKS Pod Information Collector ......"
echo "==============================================="
# https://github.com/awslabs/amazon-eks-ami/tree/master/log-collector-script/linux
sudo curl -o /usr/local/bin/plog https://raw.githubusercontent.com/aws-samples/eks-pod-information-collector/main/eks-pod-information-collector.sh
sudo chmod +x /usr/local/bin/plog
# plog -p <Pod_Name> -n <Pod_Namespace>
# plog --podname <Pod_Name> --namespace <Pod_Namespace>


echo "==============================================="
echo "  Install session-manager ......"
echo "==============================================="
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "/tmp/session-manager-plugin.rpm"
sudo yum install -y /tmp/session-manager-plugin.rpm
session-manager-plugin
# # Mac
# curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/sessionmanager-bundle.zip" -o "/tmp/sessionmanager-bundle.zip"
# unzip /tmp/sessionmanager-bundle.zip -d /tmp
# sudo /tmp/sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
# rm -fr /tmp/sessionmanager-bundle*


echo "==============================================="
echo "  Install yq for yaml processing ......"
echo "==============================================="
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq &&\
    sudo chmod +x /usr/bin/yq
# echo 'yq() {
#   docker run --rm -i -v "${PWD}":/workdir mikefarah/yq "$@"
# }' | tee -a ~/.bashrc && source ~/.bashrc


echo "==============================================="
echo "  Install wildq ......"
echo "==============================================="
# wildq: Tool on-top of jq to manipulate INI files
sudo pip3 install wildq
# cat file.ini \
#   |wildq -i ini -M '.Key = "value"' \
#   |sponge file.ini


echo "==============================================="
echo "  Install Java ......"
echo "==============================================="
# sudo amazon-linux-extras enable corretto8
# sudo yum clean metadata
# sudo yum install java-1.8.0-amazon-corretto-devel -y
sudo yum -y install java-11-amazon-corretto
#sudo alternatives --config java
#sudo update-alternatives --config javac
java -version
javac -version


echo "==============================================="
echo "  Performance Test ......"
echo "==============================================="
# siege
sudo yum install siege -y
siege -V
#siege -q -t 15S -c 200 -i URL
#ab -c 500 -n 30000 http://$(kubectl get ing -n front-end --output=json | jq -r .items[].status.loadBalancer.ingress[].hostname)/
# storage
sudo yum install fio ioping -y
## FIO command to perform load testing, and write down the IOPS and Throughput
# mkdir -p /data/performance
# cd /data/performance
# fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=fiotest --filename=testfio8gb --bs=1MB --iodepth=64 --size=8G --readwrite=randrw --rwmixread=50 --numjobs=4 --group_reporting --runtime=30
# IOping to test the latency
# sudo ioping -c 100 /efs
# vegeta https://github.com/tsenart/vegeta
curl -L "https://github.com/tsenart/vegeta/releases/download/v12.10.0/vegeta_12.10.0_linux_amd64.tar.gz" -o "/tmp/vegeta.tar.gz"
sudo tar xvzf /tmp/vegeta.tar.gz -C /usr/local/bin/
sudo chmod 755 /usr/local/bin/vegeta
vegeta -version


echo "==============================================="
echo "  Network Utilites ......"
echo "==============================================="
#https://repost.aws/knowledge-center/network-issue-vpc-onprem-ig
sudo yum -y install telnet mtr traceroute nc 
pip3 install httpie
# nc --listen 8000 # SERVER (in shell one)
# cat <<< "request" > /dev/tcp/127.0.0.1/8000 # CLIENT (in shell two)
# SERVER (hit Ctrl+C to break)
# while true; do nc --listen 8000; done
# CLIENT
# cat <<< "request 1" > /dev/tcp/127.0.0.1/8000 && sleep 1
# echo "request 2" > /dev/tcp/127.0.0.1/8000 && sleep 1
# nc 127.0.0.1 8000 <<< "request 3" && sleep 1
# nc localhost 8000 <<< "request 4"


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
sudo yum install dos2unix -y
# dos2unix xxx.sh


echo "==============================================="
echo " S3 Mountpoint ......"
echo "==============================================="
# sudo yum install fuse fuse-devel cmake3 clang-devel -y
# curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/sh.rustup.rs
# sh /tmp/sh.rustup.rs
# source "$HOME/.cargo/env"
# git clone --recurse-submodules https://github.com/awslabs/mountpoint-s3.git /tmp/mountpoint-s3
# cd /tmp/mountpoint-s3
# cargo build --release
# sudo cp ./target/release/mount-s3 /usr/local/bin/
wget https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.rpm -O /tmp/mount-s3.rpm 
sudo yum install -y /tmp/mount-s3.rpm
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
# mv/sync 等注意要加单引号，注意区域配置
# s5cmd mv 's3://xxx-iad/HFDatasets/*' 's3://xxx-iad/datasets/HF/'
# s5 --profile=xxx cp --source-region=us-west-2 s3://xxx.zip ./xxx.zip


echo "==============================================="
echo " k8sgpt ......"
echo "==============================================="
curl https://github.com/k8sgpt-ai/k8sgpt/releases/download/v0.3.21/k8sgpt_Linux_x86_64.tar.gz -o "/tmp/k8sgpt_Linux_x86_64.tar.gz"
sudo tar -xvf /tmp/k8sgpt_Linux_x86_64.tar.gz -C /usr/local/bin
echo "alias kb='k8sgpt'" | tee -a ~/.bashrc


echo "==============================================="
echo " A Data Migration Tool (abbr. ADMT) ......"
echo "==============================================="
# https://github.com/TipTopBin/data-migration-tool-for-s3


# echo "==============================================="
# echo " KMS ......"
# echo "==============================================="
# # # Create KMS
# aws kms create-alias --alias-name alias/quick-eks --target-key-id $(aws kms create-key --query KeyMetadata.Arn --output text)
# # # Set CMK ARN
# export EKS_MASTER_ARN=$(aws kms describe-key --key-id alias/quick-eks --query KeyMetadata.Arn --output text)
# echo "export EKS_MASTER_ARN=${EKS_MASTER_ARN}" | tee -a ~/.bashrc


echo "==============================================="
echo "  Expand disk space ......"
echo "==============================================="
wget https://raw.githubusercontent.com/DATACNTOP/streaming-analytics/main/utils/scripts/resize-ebs.sh -O /tmp/resize-ebs.sh
chmod +x /tmp/resize-ebs.sh
/tmp/resize-ebs.sh 300
df -ah


echo "==============================================="
echo "  Update root PATH ......"
echo "==============================================="
echo "export PATH=\$PATH:\$HOME/.local/bin:\$HOME/bin:/usr/local/bin" | sudo tee -a /root/.bashrc


# echo "==============================================="
# echo "  Shell Utils ......"
# echo "==============================================="
# echo "export PS1='$ '" >> ~/.bashrc
# source ~/.bashrc
# echo $$ # current shell PID
# ls -l /proc/$$/
# Port Forwarding
# ssh -i xxx.pem -L 8888:127.0.0.1:8888 ec2-user@my-remote-server.host


echo "==============================================="
echo "  More Aliases ......"
echo "==============================================="
# cat >> ~/.bashrc <<EOF
# alias cat=ccat
# EOF
# .vimrc
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
alias jc=/bin/journalctl
export TERM=xterm-256color
#export TERM=xterm-color
alias 2e='cd /home/ec2-user/environment'
EOF
source ~/.bashrc
# journalctl -u kubelet | grep error 
# 最后再执行一次 source
echo "source .bashrc"
shopt -s expand_aliases
. ~/.bashrc