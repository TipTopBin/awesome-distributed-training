
## 调试

```shell
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
export LC_NAME=eks # 请根据需要替换生命周期名称
export IA_S3_BUCKET=ia-${ACCOUNT_ID}-${AWS_REGION} # 请替换桶名

mkdir -p /home/ec2-user/SageMaker/custom/lifecycle && cd /home/ec2-user/SageMaker/custom/lifecycle/

wget https://raw.githubusercontent.com/TipTopBin/awesome-distributed-training/main/utils/sm-al2-init.sh -O ./sm-al2-init.sh
wget https://raw.githubusercontent.com/TipTopBin/awesome-distributed-training/main/utils/sm-al2-jupyter4.sh -O ./sm-al2-jupyter4.sh
wget https://raw.githubusercontent.com/TipTopBin/awesome-distributed-training/main/utils/sm-al2-abc.sh -O ./sm-al2-abc.sh
wget https://raw.githubusercontent.com/aws-samples/amazon-sagemaker-notebook-instance-lifecycle-config-samples/master/scripts/auto-stop-idle/autostop.py -O ./autostop.py

echo "同步回 S3 ..." # Replace with your own bucket and lifecycle name
aws s3 sync /home/ec2-user/SageMaker/custom/lifecycle/ s3://$IA_S3_BUCKET/sagemaker/lifecycle/$LC_NAME/ 

chmod +x /home/ec2-user/SageMaker/custom/lifecycle/*.sh && chown ec2-user:ec2-user /home/ec2-user/SageMaker/custom/ -R
nohup /home/ec2-user/SageMaker/custom/lifecycle/sm-al2-init.sh > /home/ec2-user/SageMaker/custom/lifecycle/sm-al2-init.log 2>&1 &  # execute asynchronously
nohup /home/ec2-user/SageMaker/custom/lifecycle/sm-al2-abc.sh > /home/ec2-user/SageMaker/custom/lifecycle/sm-al2-abc.log 2>&1 &
/home/ec2-user/SageMaker/custom/lifecycle/sm-al2-jupyter4.sh > /home/ec2-user/SageMaker/custom/lifecycle/sm-al2-jupyter4.log 2>&1
```

## 参考

- https://github.com/aws-samples/amazon-sagemaker-notebook-instance-lifecycle-config-samples
- https://github.com/aws/aws-jupyter-proxy
- https://github.com/aws-samples/amazon-sagemaker-notebook-instance-lifecycle-config-samples/blob/master/scripts/proxy-for-jupyter/on-start.sh


Persistent Jupyter Kernels
- https://medium.com/@haridada07/creating-persistent-python-kernels-for-sagemaker-63993138ae50
- https://towardsdatascience.com/installing-a-persistent-julia-environment-on-sagemaker-c67acdde9d4b
- The `/home/ec2-user/SageMaker` directory is the only path that persists between notebook instance sessions. 

