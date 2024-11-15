#!/bin/bash

source ~/.bashrc

# AI BigData Cloud
CUSTOM_DIR=/home/ec2-user/SageMaker/custom && mkdir -p "$CUSTOM_DIR"/bin
CUSTOM_BASH="${1:-/home/ec2-user/SageMaker/custom/bashrc}"

# yum update -y

echo "==============================================="
echo "  Metadata ......"
echo "==============================================="
# if [ ! -z ${SAGE_NB_NAME} ]; then
if ! grep -q "SAGE_NB_NAME" $CUSTOM_BASH; then
  echo "Add SageMaker notebook variables: SAGE_NB_URL" # Add SageMaker related ENVs if not set before
  export SAGE_NB_NAME=$(cat /opt/ml/metadata/resource-metadata.json | jq .ResourceName | tr -d '"')
  # SAGE_NB_NAME=$(cat /opt/ml/metadata/resource-metadata.json  | jq -r '.ResourceName')
  export SAGE_LC_NAME=$(aws sagemaker describe-notebook-instance --notebook-instance-name ${SAGE_NB_NAME} --query NotebookInstanceLifecycleConfigName --output text)
  export SAGE_ROLE_ARN=$(aws sagemaker describe-notebook-instance --notebook-instance-name ${SAGE_NB_NAME} --query RoleArn --output text)
  export SAGE_ROLE_NAME=$(echo ${SAGE_ROLE_ARN##*/})   # Get sagemaker role name
  export SAGE_NB_IP=$(ip addr show dev eth2 | awk '/inet / {print $2}' | awk -F/ '{print $1}')

  # export SAGE_ROLE_NAME=$(basename "$ROLE") # another way
  export SAGE_NB_URL=$(cat /etc/opt/ml/sagemaker-notebook-instance-config.json \
    | jq -r '.notebook_uri' \
    | sed 's/[\\()]//g' \
    | sed "s/|${SAGE_NB_NAME}\.notebook/.notebook/"
  )

  cat >> /home/ec2-user/SageMaker/custom/bashrc <<EOF

export SAGE_NB_NAME=$SAGE_NB_NAME
export SAGE_NB_URL=$SAGE_NB_URL
export SAGE_LC_NAME=$SAGE_LC_NAME
export SAGE_ROLE_NAME=$SAGE_ROLE_NAME
export SAGE_ROLE_ARN=$SAGE_ROLE_ARN
export SAGE_NB_IP=$SAGE_NB_IP

EOF
fi


echo "==============================================="
echo "  AI/ML ......"
echo "==============================================="
# ParallelCluster
# python3 -m pip install "aws-parallelcluster" --upgrade --user
# pcluster version

# # Ask bedrock
# pip install ask-bedrock

# if [ -f $CUSTOM_DIR/profile_bedrock_config ]; then
#   # cat $CUSTOM_DIR/profile_bedrock_config >> ~/.aws/config
#   # cat $CUSTOM_DIR/profile_bedrock_credentials >> ~/.aws/credentials
#   cp $CUSTOM_DIR/profile_bedrock_config ~/.aws/config
#   cp $CUSTOM_DIR/profile_bedrock_credentials ~/.aws/credentials  
# fi

# if [ -f $CUSTOM_DIR/abc_config ]; then
#   mkdir -p /home/ec2-user/.config/ask-bedrock
#   cp $CUSTOM_DIR/abc_config $HOME/.config/ask-bedrock/config.yaml
# fi
# # https://github.com/awslabs/mlspace
# # https://mlspace.readthedocs.io/en/latest/index.html
# # aws configure --profile bedrock
# # ask-bedrock converse
# # ask-bedrock configure

# echo "rhubarb ......"
# https://github.com/awslabs/rhubarb
# pip install pyrhubarb

echo "Local Stable Diffusion ......"
# AWS Extension https://github.com/awslabs/stable-diffusion-aws-extension/blob/main/docs/Environment-Preconfiguration.md
#wget https://raw.githubusercontent.com/TipTopBin/stable-diffusion-aws-extension/main/install.sh -O /home/ec2-user/SageMaker/custom/install-sd.sh
#sh /home/ec2-user/SageMaker/custom/install-sd.sh
#~/environment/aiml/stable-diffusion-webui/webui.sh --enable-insecure-extension-access --skip-torch-cuda-test --no-half --listen
# ~/environment/aiml/stable-diffusion-webui/webui.sh --enable-insecure-extension-access --skip-torch-cuda-test --port 8080 --no-half --listen
# Docker https://github.com/TipTopBin/stable-diffusion-webui-docker.git
if [ ! -z "$SD_HOME" ]; then
  cd $SD_HOME/sd-webui # WorkingDirectory 注意一定要进入到这个目录
  # TODO check GPU
  nohup $SD_HOME/sd-webui/webui.sh --gradio-auth admin:${SD_PWD} --cors-allow-origins=* --enable-insecure-extension-access --allow-code --medvram --xformers --listen --port 8760 > $SD_HOME/sd.log 2>&1 & # execute asynchronously
fi
# https://github.com/awslabs/stable-diffusion-aws-extension/blob/main/docs/Environment-Preconfiguration.md
# wget https://raw.githubusercontent.com/awslabs/stable-diffusion-aws-extension/main/install.sh -O ~/environment/aiml/install-sd.sh
# sh ~/environment/aiml/install-sd.sh
# # CPU 如果遇到 pip 找不到错误，尝试更新到 Python 3.8+，然后重启
# ~/environment/aiml/stable-diffusion-webui/webui.sh --enable-insecure-extension-access --skip-torch-cuda-test --no-half --listen
# ~/environment/aiml/stable-diffusion-webui/webui.sh --enable-insecure-extension-access --skip-torch-cuda-test --port 8080 --no-half --listen

# persistent kaggle
mkdir -p $CUSTOM_DIR/kaggle
ln -s $CUSTOM_DIR/kaggle ~/.kaggle


echo "Install Jupyter Extensions ......"
# 特意不放在 sm-al2-jupyter.sh 需要等前置升级完成，并且重启后再执行
source /home/ec2-user/anaconda3/bin/activate JupyterSystemEnv
pip install amazon-codewhisperer-jupyterlab-ext
jupyter server extension enable amazon_codewhisperer_jupyterlab_ext

# jupyterlab-lsp 需要的时候手动装
# # https://github.com/jupyter-lsp/jupyterlab-lsp
# # https://github.com/aws-samples/sagemaker-studio-lifecycle-config-examples/blob/main/scripts/install-lsp-features/on-jupyter-server-start.sh
# echo "Installing jupyterlab-lsp and language tools"
# # 保持简单，启用多个反而会有冲突
# pip install jupyterlab-lsp \
#     'python-lsp-server[fall]'
#     # jupyterlab-spellchecker
#     # jupyterlab-code-formatter
# #     'python-lsp-server[flake8,mccabe,pycodestyle,pydocstyle,pyflakes,pylint,rope]' \
# #     black isort    

# # Some LSP language servers install via JS, not Python. For full list of language servers see:
# # https://jupyterlab-lsp.readthedocs.io/en/stable/Language%20Servers.html
# # jlpm add --dev bash-language-server@"<5.0.0" dockerfile-language-server-nodejs
# npm install --save-dev bash-language-server@"<5.0.0" dockerfile-language-server-nodejs unified-language-server vscode-json-languageserver-bin yaml-language-server

# # This configuration override is optional, to make LSP "extra-helpful" by default:
# CMP_CONFIG_DIR=~/.jupyter/lab/user-settings/@jupyter-lsp/jupyterlab-lsp/
# CMP_CONFIG_FILE=completion.jupyterlab-settings
# CMP_CONFIG_PATH="$CMP_CONFIG_DIR/$CMP_CONFIG_FILE"
# if test -f $CMP_CONFIG_PATH; then
#     echo "jupyterlab-lsp config file already exists: Skipping default config setup"
# else
#     echo "Setting continuous hinting to enabled by default"
#     mkdir -p $CMP_CONFIG_DIR
#     echo '{ "continuousHinting": true }' > $CMP_CONFIG_PATH
# fi

# # jupyter server extension enable --sys-prefix jupyterlab-lsp jupyterlab-spellchecker # 需要启用，否则会有兼容问题
# jupyter server extension enable jupyterlab-lsp --sys-prefix
# # jupyter server extension list --generate-config
# # jupyter server extension disable jupyterlab-lsp


# # 允许访问其他位置的包/代码
# cat >> ~/.jupyter/jupyter_server_config.py <<EOF
# c.ContentsManager.allow_hidden = True
# EOF
# # 代码跳转设置
# if [ ! -L ~/SageMaker/.lsp_symlink ]; then
#   cd ~/SageMaker # 进入 jupyter 根目录
#   ln -s / .lsp_symlink
# fi

source /home/ec2-user/anaconda3/bin/deactivate


# # https://docs.conda.io/en/latest/miniconda.html
# # https://github.com/aws-samples/amazon-sagemaker-notebook-instance-lifecycle-config-samples/blob/master/scripts/persistent-conda-ebs/on-create.sh
# # installs a custom, persistent installation of conda on the Notebook Instance's EBS volume, and ensures
# # The on-create script downloads and installs a custom conda installation to the EBS volume via Miniconda. Any relevant
# # packages can be installed here.
# #   1. ipykernel is installed to ensure that the custom environment can be used as a Jupyter kernel   
# #   2. Ensure the Notebook Instance has internet connectivity to download the Miniconda installer

# CONDA_DIRECTORY="/home/ec2-user/SageMaker/custom/miniconda"
# if [ -d "$CONDA_DIRECTORY" ]; then
#     echo "$CONDA_DIRECTORY exists."
# else
#     echo "Setup Persistant Conda."
#     sudo -u ec2-user -i <<'EOF'
# unset SUDO_UID

# # Install a separate conda installation via Miniconda
# WORKING_DIR=/home/ec2-user/SageMaker/custom
# mkdir -p "$WORKING_DIR"
# # wget https://repo.anaconda.com/miniconda/Miniconda3-4.6.14-Linux-x86_64.sh -O "$WORKING_DIR/miniconda.sh"
# wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O "$WORKING_DIR/miniconda.sh"
# bash "$WORKING_DIR/miniconda.sh" -b -u -p "$WORKING_DIR/miniconda" 
# rm -rf "$WORKING_DIR/miniconda.sh"
# EOF
# fi


## 2021
# # wget https://repo.anaconda.com/archive/Anaconda3-2021.05-Linux-x86_64.sh
# # bash Anaconda3-2021.05-Linux-x86_64.sh -b -p /home/ec2-user/anaconda3
# wget -O /tmp/Anaconda3-2021.05-Linux-x86_64.sh https://repo.anaconda.com/archive/Anaconda3-2021.05-Linux-x86_64.sh
# bash /tmp/Anaconda3-2021.05-Linux-x86_64.sh -b -p /home/ec2-user/environment/anaconda3
## 2022
# wget -O /tmp/Anaconda3-2022.10-Linux-x86_64.sh https://repo.anaconda.com/archive/Anaconda3-2022.10-Linux-x86_64.sh
# bash /tmp/Anaconda3-2022.10-Linux-x86_64.sh -b -p /home/ec2-user/environment/aiml/anaconda3
# cat >> ~/.bashrc <<EOF
# export PATH="/home/ec2-user/environment/aiml/anaconda3/bin:\$PATH"
# EOF
# source ~/.bashrc
# conda config --show
# conda info --envs
# conda init
## create a new conda environment
# conda create -y -n builder --override-channels --strict-channel-priority -c conda-forge -c nodefaults jupyterlab=3 cookiecutter nodejs jupyter-packaging git build
## remove environment
# conda remove -n builder --all
## switch environment
# conda activate builder
## start jupyter lab
## Preview Running Application -> Pop Out Into New Window (建议 ChromeFirefox 页面无法展示)
# . /home/ec2-user/environment/aiml/anaconda3/etc/profile.d/conda.sh
# conda activate builder
# jupyter lab --port=8080 --ServerApp.allow_remote_access=True


# echo "Jupyter ......"
# # https://studio.us-east-1.prod.workshops.aws/workshops/public/9cc3f765-77c6-4255-99a1-8e98ff483347
# # touch /home/ec2-user/jupyterpassword.py
# # echo "from notebook.auth import passwd" | cat >> /home/ec2-user/jupyterpassword.py
# # echo "import os" | cat >> jupyterpassword.py
# # echo "print(passwd('Awslabs'))" | cat >> /home/ec2-user/jupyterpassword.py
# cat > /home/ec2-user/environment/aiml/jupyterpassword.py <<EOF
# from notebook.auth import passwd
# import random, string
# generated_string = ''.join(random.SystemRandom().choice(string.ascii_letters + string.digits) for _ in range(17))
# f = open("/home/ec2-user/environment/aiml/jupyterpassword.txt", "w")
# f.write(generated_string)
# f.close()
# print(passwd(generated_string))
# EOF

# # echo "eval \"\$(/home/ec2-user/anaconda3/bin/conda shell.bash hook)\"" | cat >> /home/ec2-user/jupytersetup.sh
# # echo "conda init" | cat >> /home/ec2-user/jupytersetup.sh
# # echo "jupyter notebook --generate-config" | cat >> /home/ec2-user/jupytersetup.sh

# # a="encrypted_pwd=\$(python3 /home/ec2-user/jupyterpassword.py)"
# # echo $a | cat >> /home/ec2-user/jupytersetup.sh
# # b="sed -i 's/c = get_config()/#c = get_config()/' /root/.jupyter/jupyter_notebook_config.py"
# # echo $b | cat >> /home/ec2-user/jupytersetup.sh
# # c="sed -i \"1 i\\c.NotebookApp.password=\\'\$encrypted_pwd\'\" /root/.jupyter/jupyter_notebook_config.py"
# # echo $c | cat >> /home/ec2-user/jupytersetup.sh
# # d="sed -i '1 i\\c.NotebookApp.port=8888' /root/.jupyter/jupyter_notebook_config.py"
# # echo $d | cat >> /home/ec2-user/jupytersetup.sh
# # e="sed -i '1 i\\c.NotebookApp.open_browser=False' /root/.jupyter/jupyter_notebook_config.py"
# # echo $e | cat >> /home/ec2-user/jupytersetup.sh
# # f="sed -i \"1 i\\c.NotebookApp.ip='*'\" /root/.jupyter/jupyter_notebook_config.py"
# # echo $f | cat >> /home/ec2-user/jupytersetup.sh

# echo "eval \"\$(/home/ec2-user/environment/aiml/anaconda3/bin/conda shell.bash hook)\"" | cat >> /home/ec2-user/environment/aiml/jupytersetup.sh
# echo "conda init" | cat >> /home/ec2-user/environment/aiml/jupytersetup.sh
# echo "jupyter notebook --generate-config" | cat >> /home/ec2-user/environment/aiml/jupytersetup.sh

# a="encrypted_pwd=\$(python3 /home/ec2-user/environment/aiml/jupyterpassword.py)"
# echo $a | cat >> /home/ec2-user/environment/aiml/jupytersetup.sh
# b="sed -i 's/c = get_config()/#c = get_config()/' /root/.jupyter/jupyter_notebook_config.py"
# echo $b | cat >> /home/ec2-user/environment/aiml/jupytersetup.sh
# c="sed -i \"1 i\\c.NotebookApp.password=\\'\$encrypted_pwd\'\" /root/.jupyter/jupyter_notebook_config.py"
# echo $c | cat >> /home/ec2-user/environment/aiml/jupytersetup.sh
# d="sed -i '1 i\\c.NotebookApp.port=8888' /root/.jupyter/jupyter_notebook_config.py"
# echo $d | cat >> /home/ec2-user/environment/aiml/jupytersetup.sh
# e="sed -i '1 i\\c.NotebookApp.open_browser=False' /root/.jupyter/jupyter_notebook_config.py"
# echo $e | cat >> /home/ec2-user/environment/aiml/jupytersetup.sh
# f="sed -i \"1 i\\c.NotebookApp.ip='*'\" /root/.jupyter/jupyter_notebook_config.py"
# echo $f | cat >> /home/ec2-user/environment/aiml/jupytersetup.sh

# # setup in root 
# sudo su
# chmod +x /home/ec2-user/environment/aiml/jupytersetup.sh
# /home/ec2-user/environment/aiml/jupytersetup.sh
# source ~/.bashrc
# # conda -V
# exit

# # manage in ec2-user
# echo "export PATH=/home/ec2-user/environment/anaconda3/bin:\$PATH" | sudo tee -a ~/.bashrc
# source ~/.bashrc
# mkdir /home/ec2-user/environment/notebooks

# ## start up example (run as root)
# # sudo su
# # cd /home/ec2-user/environment/notebooks
# # jupyter notebook --allow-root


# echo "Griptape ......"
# # # https://blog.beachgeek.co.uk/getting-started-with-griptape/
# # # https://www.griptape.ai/
# # cd ~/environment/aiml
# # python -m venv griptape
# # cd griptape/
# # source bin/activate


echo "==============================================="
echo "  BigData ......"
echo "==============================================="
# echo "  Data on Amazon EKS (DoEKS) ......"
# git clone https://github.com/TipTopBin/data-on-eks.git ~/environment/do/data-on-eks


if [ ! -f $CUSTOM_DIR/flink-1.16.3/bin/flink ]; then
  echo "Setup Flink 1.16"
  wget https://dlcdn.apache.org/flink/flink-1.16.3/flink-1.16.3-bin-scala_2.12.tgz
  # wget https://archive.apache.org/dist/flink/flink-1.15.3/flink-1.15.3-bin-scala_2.12.tgz -O /tmp/flink-1.15.3.tgz
  sudo tar xzvf flink-*.tgz -C $CUSTOM_DIR/
  sudo chown -R ec2-user $CUSTOM_DIR/flink-1.16.3
  # flink -v
  cat >> ~/SageMaker/custom/bashrc <<EOF
export PATH="$CUSTOM_DIR/flink-1.16.3/bin:\$PATH"
EOF

fi

# if [ ! -f $CUSTOM_DIR/flink-1.15.3/bin/flink ]; then
#   echo "Setup Flink 1.15"
#   wget https://archive.apache.org/dist/flink/flink-1.15.3/flink-1.15.3-bin-scala_2.12.tgz -O /tmp/flink-1.15.3.tgz
#   sudo tar xzvf /tmp/flink-1.15.3.tgz -C $CUSTOM_DIR/
#   sudo chown -R ec2-user $CUSTOM_DIR/flink-1.15.3
#   # flink -v
#   cat >> ~/SageMaker/custom/bashrc <<EOF
# export PATH="$CUSTOM_DIR/flink-1.15.3/bin:\$PATH"
# EOF


echo "
Setting system-wide JAVA_HOME to enable .ipynb to run pyspark-2.x (from the
conda_python3 kernel), directly on this notebook instance.

- This version of pyspark requires Java-1.8. However, since some time in 2021,
  every .ipynb notebooks will automatically inherit
  os.environ['JAVA_HOME'] == '/home/ec2-user/anaconda3/envs/JupyterSystemEnv',
  and this OpenJDK-11 breaks the pyspark-2.x.

- Note that setting JAVA_HOME in ~/.bashrc is not sufficient, because it affects
  only pyspark scripts or REPL ran from a terminal.
"

echo 'export JAVA_HOME=/usr/lib/jvm/java' | sudo tee -a /etc/profile.d/java.sh


# echo "  Kafka ......"
# wget https://archive.apache.org/dist/kafka/2.8.1/kafka_2.12-2.8.1.tgz -O /tmp/kafka_2.12-2.8.1.tgz
# tar -xzf /tmp/kafka_2.12-2.8.1.tgz -C ~/environment/do/
# sudo chown -R ec2-user ~/environment/do
# cat >> ~/.bashrc <<EOF
# export PATH="~/environment/do/kafka_2.12-2.8.1/bin:$PATH"
# EOF
# source ~/.bashrc
# # ln -s kafka_2.12-2.8.1 kafka


# echo "  Install Cruise Control ......"
# git clone https://github.com/linkedin/cruise-control.git ~/environment/do/cruise-control && cd ~/environment/do/cruise-control/
# ./gradlew jar copyDependantLibs
# mkdir logs; touch logs/kafka-cruise-control.out
# # export MSK_ARN=`aws kafka list-clusters|grep ClusterArn|cut -d ':' -f 2-|cut -d ',' -f 1 | sed -e 's/\"//g'`
# export MSK_ARN=$(aws kafka list-clusters --output json | jq -r .ClusterInfoList[].ClusterArn)
# # export MSK_BROKERS=`aws kafka get-bootstrap-brokers --cluster-arn $MSK_ARN|grep BootstrapBrokerString|grep 9092| cut -d ':' -f 2- | sed -e 's/\"//g' | sed -e 's/,$//'`
# export MSK_BROKERS=$(aws kafka get-bootstrap-brokers --cluster-arn $MSK_ARN --output json | jq -r .BootstrapBrokerString)
# # export MSK_ZOOKEEPER=`aws kafka describe-cluster --cluster-arn $MSK_ARN|grep ZookeeperConnectString|grep -v Tls|cut -d ':' -f 2-|sed 's/,$//g'|sed -e 's/\"//g'`
# export MSK_ZOOKEEPER=$(aws kafka describe-cluster --cluster-arn $MSK_ARN|grep ZookeeperConnectString|grep -v Tls|cut -d ':' -f 2-|sed 's/,$//g'|sed -e 's/\"//g')
# echo "export MSK_ARN=\"${MSK_ARN}\"" | tee -a ~/.bashrc
# echo "export MSK_BROKERS=\"${MSK_BROKERS}\"" | tee -a ~/.bashrc
# echo "export MSK_ZOOKEEPER=\"${MSK_ZOOKEEPER}\"" >> ~/.bashrc
# source ~/.bashrc

# # sed -i "s/localhost:9092/${MSK_BROKERS}/g" config/cruisecontrol.properties
# # sed -i "s/localhost:2181/${MSK_ZOOKEEPER}/g" config/cruisecontrol.properties
# # sed -i "s/webserver.http.port=9090/webserver.http.port=8080/g" config/cruisecontrol.properties 
# # sed -i "s/capacity.config.file=config\/capacityJBOD.json/capacity.config.file=.\/config\/capacityCores.json/g" config/cruisecontrol.properties
# # sudo chmod -R 777 .
# # # sed -i "s/com.linkedin.kafka.cruisecontrol.monitor.sampling.CruiseControlMetricsReporterSampler/com.linkedin.kafka.cruisecontrol.monitor.sampling.prometheus.PrometheusMetricSampler/g" config/cruisecontrol.properties
# # # echo "prometheus.server.endpoint=localhost:9090" >> config/cruisecontrol.properties
# # update capacityCores.json
# # # start 
# # cd ~/environment/do/cruise-control/
# # ./kafka-cruise-control-start.sh -daemon config/cruisecontrol.properties
# wget https://github.com/linkedin/cruise-control-ui/releases/download/v0.3.4/cruise-control-ui-0.3.4.tar.gz  -O /tmp/cruise-control-ui-0.3.4.tar.gz
# sudo tar xzvf /tmp/cruise-control-ui-0.3.4.tar.gz -C ~/environment/do/cruise-control/
# sudo chown -R ec2-user ~/environment/do/cruise-control/



# echo "  Install emr-on-eks-custom-image ......"
# wget -O /tmp/amazon-emr-on-eks-custom-image-cli-linux.zip https://github.com/awslabs/amazon-emr-on-eks-custom-image-cli/releases/download/v1.03/amazon-emr-on-eks-custom-image-cli-linux-v1.03.zip
# sudo mkdir -p /opt/emr-on-eks-custom-image
# unzip /tmp/amazon-emr-on-eks-custom-image-cli-linux.zip -d /opt/emr-on-eks-custom-image
# sudo /opt/emr-on-eks-custom-image/installation
# emr-on-eks-custom-image --version
# cat >> ~/.bashrc <<EOF
# alias eec=emr-on-eks-custom-image
# EOF
# source ~/.bashrc
# eec --version


# echo "  mwaa-local-runner ......"
# # https://dev.to/aws/getting-mwaa-local-runner-up-on-aws-cloud9-1nhd


# echo "  postgresql ......"
# # https://catalog.workshops.aws/performance-tuning/en-US/30-environment
# sudo amazon-linux-extras install -y python3.8 postgresql14
# sudo yum install -y jq postgresql-contrib


# echo "  mysql ......"
# wget -c https://dev.mysql.com/get/Downloads/MySQL-Shell/mysql-shell-8.0.32-linux-glibc2.12-x86-64bit.tar.gz
# tar -xf mysql-shell-8.0.32-linux-glibc2.12-x86-64bit.tar.gz
# mysqlsh


echo "==============================================="
echo " Cloud Native ......"
echo "==============================================="
# moreutils: The command sponge allows us to read and write to the same file (cat a.txt|sponge a.txt)
sudo yum groupinstall "Development Tools" -y
sudo yum -y install jq gettext bash-completion moreutils openssl zsh xsel xclip amazon-efs-utils nc telnet mtr traceroute netcat graphviz lynx
#envsubst for environment variables substitution (envsubst is included in gettext package)
yum -y install openssl-devel bzip2-devel expat-devel gdbm-devel readline-devel sqlite-devel
# sudo yum -y install siege fio ioping dos2unix

if [ ! -f $CUSTOM_DIR/bin/yq ]; then
  wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O $CUSTOM_DIR/bin/yq
  chmod +x $CUSTOM_DIR/bin/yq
fi

#https://github.com/lutzroeder/netron
pip install netron
# pip install cleanipynb # cleanipynb xxx.ipynb # 注意会把所有的图片附件都清掉
netron --version
# netron [FILE] or netron.start('[FILE]').
python3 -m pip install awscurl
pip3 install httpie


if [ ! -f $CUSTOM_DIR/bin/devpod ]; then
  curl -L -o $CUSTOM_DIR/bin/devpod "https://github.com/loft-sh/devpod/releases/latest/download/devpod-linux-amd64" 
  # sudo install -c -m 0755 $CUSTOM_DIR/bin/devpod $CUSTOM_DIR/bin
  chmod 0755 $CUSTOM_DIR/bin/devpod
fi


if [ ! -f $CUSTOM_DIR/apache-maven-3.8.6/bin/mvn ]; then
  echo "  Install Maven ......"
  wget https://archive.apache.org/dist/maven/maven-3/3.8.6/binaries/apache-maven-3.8.6-bin.tar.gz -O /tmp/apache-maven-3.8.6-bin.tar.gz
  sudo tar xzvf /tmp/apache-maven-3.8.6-bin.tar.gz -C $CUSTOM_DIR
  cat >> ~/SageMaker/custom/bashrc <<EOF
export PATH="$CUSTOM_DIR/apache-maven-3.8.6/bin:\$PATH"
EOF
  # mvn --version  
fi


# echo "  Cloudscape ......"
# https://cloudscape.design/get-started/integration/using-cloudscape-components/


# echo " VS Code ......"
# https://aws.amazon.com/blogs/machine-learning/host-code-server-on-amazon-sagemaker/
# curl -L https://github.com/aws-samples/amazon-sagemaker-codeserver/releases/download/v0.1.5/amazon-sagemaker-codeserver-0.1.5.tar.gz -o /home/ec2-user/SageMaker/custom/amazon-sagemaker-codeserver-0.1.5.tar.gz
# tar -xvzf /home/ec2-user/SageMaker/custom/amazon-sagemaker-codeserver-0.1.5.tar.gz -d /home/ec2-user/SageMaker/custom/ 
# cd /home/ec2-user/SageMaker/custom/amazon-sagemaker-codeserver/install-scripts/notebook-instances
# chmod +x *.sh
# sudo ./install-codeserver.sh
# sudo ./setup-codeserver.sh
# Another way
# conda install -y -c conda-forge code-server
# code-server --auth none


# echo " resource-lister ......"
# # https://github.com/awslabs/resource-lister
# python3 -m pip install pipx
# python3 -m pip install boto3
# python3 -m pipx install resource-lister
# # pipx run resource_lister
# # python3 -m pipx run resource_lister

# echo "  Install ccat ......"
# go install github.com/owenthereal/ccat@latest
# cat >> ~/.bashrc <<EOF
# alias cat=ccat
# EOF
# source ~/.bashrc


# echo "  CDK ......"
## switch back to CDK 1.x
# https://www.npmjs.com/package/aws-cdk?activeTab=versions
# npm uninstall aws-cdk
# npm install -g aws-cdk@1.199.0
# npm install -g aws-cdk@1.199.0 --force
## Upgrade to latest version
# sudo npm install -g aws-cdk
# cdk --version

# echo "  Install ParallelCluster ......"
# if ! command -v pcluster &> /dev/null
# then
#   echo ">> pcluster is missing, reinstalling it"
#   sudo pip3 install 'aws-parallelcluster'
# else
#   echo ">> Pcluster $(pcluster version) found, nothing to install"
# fi
# pcluster version



# echo "  SAM ......"
# cd /tmp
# wget https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip
# unzip aws-sam-cli-linux-x86_64.zip -d sam-installation
# sudo ./sam-installation/install
# sam --version
# cd -


# echo "  cargo ......"
# curl https://sh.rustup.rs -sSf | sh
# source ~/.bashrc
# sudo yum install -y openssl-devel
# cargo install drill


# echo "  Install terraform ......"
# sudo yum install -y yum-utils
# sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
# sudo yum install terraform -y
# echo "alias tf='terraform'" >> ~/.bashrc
# echo "alias tfp='terraform plan -out tfplan'" >> ~/.bashrc
# echo "alias tfa='terraform apply --auto-approve'" >> ~/.bashrc # terraform apply tfplan
# source ~/.bashrc
# terraform --version


# Python
# echo "  pyenv ......"
# git clone https://github.com/pyenv/pyenv.git ~/.pyenv
# cat << 'EOT' >> ~/.bashrc
# export PYENV_ROOT="$HOME/.pyenv"
# export PATH="$HOME/.pyenv/bin:$PATH"
# eval "$(pyenv init -)"
# EOT
# # echo -e 'if command -v pyenv 1>/dev/null 2>&1; then\n  eval "$(pyenv init -)"\nfi' >> ~/.bashrc
# source ~/.bashrc


# echo "  Upgrade Python ......"
# # https://gist.github.com/094459/3eba3e5f4fb1ccaef1cb12044412f90b
# ## use amazon-linux-extras to install python 3.8
# # sudo amazon-linux-extras install python3.8 -y
# # python -m ensurepip --upgrade --user
# # sudo pip3 install --upgrade pip
# # sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1
# # sudo update-alternatives --set python3 /usr/local/bin/python3.8
# ## use pyenv to install python 3.9 (about 5 minutes to finish)
# sudo yum -y update
# sudo yum -y install bzip2-devel xz-devel
# pyenv install 3.9.15
# pyenv global 3.9.15
# export PATH="$HOME/.pyenv/shims:$PATH"
# source ~/.bash_profile
# python --version
# ## pyenv-virtualenv
# git clone https://github.com/pyenv/pyenv-virtualenv.git $(pyenv root)/plugins/pyenv-virtualenv
# echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
# . ~/.bashrc


# NodeJS
echo " Setup nvm ......"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
chmod ug+x ~/.nvm/nvm.sh
source ~/.nvm/nvm.sh # . ~/.nvm/nvm.sh
nvm -v

# https://github.com/nodejs/release#release-schedule
# LTS
# nvm install --lts
# node --version
 
# node v16 Gallium
# nvm install 16
nvm install --lts=Gallium
# node v18 Hydrogen
# nvm install --lts=Hydrogen
# node -e "console.log('Running Node.js ' + process.version)"

# uninstall
# nvm uninstall 17



# ## npm
# npm list --depth=0
# ## Redoc https://github.com/Redocly/redoc
# # npm i
# # npm run watch
# # npm install -g esbuild


# Vim
VIM_SM_ROOT=/home/ec2-user/SageMaker/custom
VIM_RTP=${VIM_SM_ROOT}/.vim
VIMRC=${VIM_SM_ROOT}/.vimrc

apply_vim_setting() {
    # vimrc
    [[ -f ~/.vimrc ]] && rm ~/.vimrc
    ln -s ${VIMRC} ~/.vimrc

    echo "Vim initialized"
}

if [[ ! -f ${VIM_RTP}/_SUCCESS ]]; then
    echo "Initializing vim from ${VIMRC_SRC}"

    # vimrc
    cat << EOF > ${VIMRC}
set rtp+=${VIM_RTP}

" Hybrid line numbers
"
" Prefer built-in over RltvNmbr as the later makes vim even slower on
" high-latency aka. cross-region instance.
:set number relativenumber
:augroup numbertoggle
:  autocmd!
:  autocmd BufEnter,FocusGained,InsertLeave * set relativenumber
:  autocmd BufLeave,FocusLost,InsertEnter   * set norelativenumber
:augroup END

" Relative number only on focused-windows
autocmd BufEnter,FocusGained,InsertLeave,WinEnter * if &number | set relativenumber   | endif
autocmd BufLeave,FocusLost,InsertEnter,WinLeave   * if &number | set norelativenumber | endif

" Remap keys to navigate window aka split screens to ctrl-{h,j,k,l}
" See: https://vi.stackexchange.com/a/3815
"
" Vim defaults to ctrl-w-{h,j,k,l}. However, ctrl-w on Linux (and Windows)
" closes browser tab.
"
" NOTE: ctrl-l was "clear and redraw screen". The later can still be invoked
"       with :redr[aw][!]
nmap <C-h> <C-w>h
nmap <C-j> <C-w>j
nmap <C-k> <C-w>k
nmap <C-l> <C-w>l

set laststatus=2
set hlsearch
set colorcolumn=80
set splitbelow
set splitright

"set cursorline
"set lazyredraw
set nottyfast

autocmd FileType help setlocal number

""" Coding style
" Prefer spaces to tabs
set tabstop=4
set shiftwidth=4
set expandtab
set nowrap
set foldmethod=indent
set foldlevel=99
set smartindent
filetype plugin indent on

""" Shortcuts
map <F3> :set paste!<CR>
" Use <leader>l to toggle display of whitespace
nmap <leader>l :set list!<CR>

" Highlight trailing space without plugins
highlight RedundantSpaces ctermbg=red guibg=red
match RedundantSpaces /\s\+$/

" Terminado supports 256 colors
set t_Co=256
"colorscheme delek
"colorscheme elflord
"colorscheme murphy
"colorscheme ron
highlight colorColumn ctermbg=237

EOF
    mkdir -p ${VIM_RTP}
    touch ${VIM_RTP}/_SUCCESS
fi

apply_vim_setting