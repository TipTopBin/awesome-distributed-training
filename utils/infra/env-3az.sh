#!/bin/bash

source ~/.bashrc

# Tag to Env
# https://github.com/aws-samples/amazon-sagemaker-notebook-instance-lifecycle-config-samples/blob/master/scripts/set-env-variable/on-start.sh

BASH_FILE="${1:-~/.bashrc}"
NAME_PREFIX="sage"

echo "==============================================="
echo "  Config envs ......"
echo "==============================================="
# export AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')
export AWS_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
test -n "$AWS_REGION" && echo AWS_REGION is "$AWS_REGION" || echo AWS_REGION is not set
echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ${BASH_FILE}
echo "export AWS_REGION=${AWS_REGION}" | tee -a ${BASH_FILE}
# export AZS=($(aws ec2 describe-availability-zones --query 'AvailabilityZones[].ZoneName' --output text --region $AWS_REGION))
# echo "export AZS=${AZS}" | tee -a ${BASH_FILE}
# echo "export AZS=(${AZS[@]})" | tee -a ${BASH_FILE}
aws configure set default.region ${AWS_REGION}
aws configure get default.region
aws configure set region $AWS_REGION
export EKS_VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${NAME_PREFIX}-VPC" --query 'Vpcs[0].VpcId' --output text)
export EKS_VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids $EKS_VPC_ID --query 'Vpcs[0].{CidrBlock:CidrBlock}' --output text)
# 注意 filter 区分大小写
EKS_PUBAZ_INFO_LIST=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${EKS_VPC_ID}"  "Name=tag:Name,Values=*${NAME_PREFIX}-PublicELB*" | jq '.Subnets | sort_by(.AvailabilityZone)' | jq '.[] | .SubnetId+","+.AvailabilityZone+","+.AvailabilityZoneId')
SUB_IDX=1
for pubazinfo in $EKS_PUBAZ_INFO_LIST
do
	export info_str=$(echo "$pubazinfo" | tr -d '"') # 去掉双引号
  IFS=',' read -ra info_array <<< "$info_str"
	echo "export EKS_PUB_SUBNET_$SUB_IDX=${info_array[0]}" >> ${BASH_FILE}
	echo "export EKS_AZ_$SUB_IDX=${info_array[1]}" >> ${BASH_FILE}
	echo "export EKS_AZ_ID_$SUB_IDX=${info_array[2]}" >> ${BASH_FILE}
	((SUB_IDX++))
done
# private 子网
EKS_PRI_SUBNET_LIST=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${EKS_VPC_ID}"  "Name=tag:Name,Values=*${NAME_PREFIX}-Private*" "Name=cidr-block,Values=*$(echo $EKS_VPC_CIDR | cut -d . -f 1).$(echo $EKS_VPC_CIDR | cut -d . -f 2).*" | jq '.Subnets | sort_by(.AvailabilityZone)' | jq '.[] .SubnetId')
SUB_IDX=1
for subnet in $EKS_PRI_SUBNET_LIST
do
	echo "export EKS_PRI_SUBNET_$SUB_IDX=$subnet" >> ${BASH_FILE}
	((SUB_IDX++))
done
# pod 子网
EKS_POD_SUBNET_LIST=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${EKS_VPC_ID}"  "Name=tag:Name,Values=*${NAME_PREFIX}-Pod*" "Name=cidr-block,Values=*100.66.*" | jq '.Subnets | sort_by(.AvailabilityZone)' | jq '.[] .SubnetId')
SUB_IDX=1
for subnet in $EKS_POD_SUBNET_LIST
do
	echo "export EKS_POD_SUBNET_$SUB_IDX=$subnet" >> ${BASH_FILE}
	((SUB_IDX++))
done
# Additional security groups, 1
export EKS_CLUSTER_SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$EKS_VPC_ID"  "Name=tag:Name,Values=*${NAME_PREFIX}-control-plane*" | jq -r '.SecurityGroups[]|.GroupId')
# Additional security groups, 2
export EKS_ADDITIONAL_SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$EKS_VPC_ID"  "Name=tag:Name,Values=*${NAME_PREFIX}-additional*" | jq -r '.SecurityGroups[]|.GroupId')
# Custom network security groups
export EKS_CUSTOMNETWORK_SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$EKS_VPC_ID"  "Name=tag:Name,Values=*${NAME_PREFIX}-custom-network*" | jq -r '.SecurityGroups[]|.GroupId')
# Share node security group
export EKS_SHAREDNODE_SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$EKS_VPC_ID"  "Name=tag:Name,Values=*${NAME_PREFIX}-shared-node*" | jq -r '.SecurityGroups[]|.GroupId')  
# Extrenal security group
export EKS_EXTERNAL_SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$EKS_VPC_ID"  "Name=tag:Name,Values=*${NAME_PREFIX}-external*" | jq -r '.SecurityGroups[]|.GroupId')

echo "export EKS_VPC_ID=\"$EKS_VPC_ID\"" >> ${BASH_FILE}
echo "export EKS_VPC_CIDR=\"$EKS_VPC_CIDR\"" >> ${BASH_FILE}
echo "export EKS_CLUSTER_SG=${EKS_CLUSTER_SG}" | tee -a ${BASH_FILE}
echo "export EKS_ADDITIONAL_SG=${EKS_ADDITIONAL_SG}" | tee -a ${BASH_FILE}
echo "export EKS_CUSTOMNETWORK_SG=${EKS_CUSTOMNETWORK_SG}" | tee -a ${BASH_FILE}
echo "export EKS_SHAREDNODE_SG=${EKS_SHAREDNODE_SG}" | tee -a ${BASH_FILE}
echo "export EKS_EXTERNAL_SG=${EKS_EXTERNAL_SG}" | tee -a ${BASH_FILE}

source ~/.bashrc
aws sts get-caller-identity