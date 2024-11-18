#!/bin/bash

source ~/.bashrc

# Tag to Env
# https://github.com/aws-samples/amazon-sagemaker-notebook-instance-lifecycle-config-samples/blob/master/scripts/set-env-variable/on-start.sh

# BASH_FILE="${1:-~/.bashrc}"
BASH_FILE="${1:-$HOME/.bashrc}"
NAME_PREFIX="SageVPC"

echo "==============================================="
echo "  Config envs ......"
echo "==============================================="
if ! grep -q "PRI_SUBNET_1" "$BASH_FILE"; then 
    # Add infra envs if not set before
	echo "# Start adding by env.sh" | tee -a ${BASH_FILE}
	# export AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')
	export AWS_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
	export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
	test -n "$AWS_REGION" && echo AWS_REGION is "$AWS_REGION" || echo AWS_REGION is not set
	# export AZS=($(aws ec2 describe-availability-zones --query 'AvailabilityZones[].ZoneName' --output text --region $AWS_REGION))
	# echo "export AZS=${AZS}" | tee -a ${BASH_FILE}
	# echo "export AZS=(${AZS[@]})" | tee -a ${BASH_FILE}
	aws configure set default.region ${AWS_REGION}
	aws configure get default.region
	aws configure set region $AWS_REGION
	export EKS_VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${NAME_PREFIX}" --query 'Vpcs[0].VpcId' --output text)
	export EKS_VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids $EKS_VPC_ID --query 'Vpcs[0].{CidrBlock:CidrBlock}' --output text)
	# 注意 filter 区分大小写
	EKS_PUBAZ_INFO_LIST=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${EKS_VPC_ID}"  "Name=tag:Name,Values=*${NAME_PREFIX}-PublicELB*" | jq '.Subnets | sort_by(.AvailabilityZone)' | jq '.[] | .SubnetId+","+.AvailabilityZone+","+.AvailabilityZoneId')
	SUB_IDX=1
	for pubazinfo in $EKS_PUBAZ_INFO_LIST
	do
		export info_str=$(echo "$pubazinfo" | tr -d '"') # 去掉双引号
	IFS=',' read -ra info_array <<< "$info_str"
		echo "export PUB_SUBNET_$SUB_IDX=${info_array[0]}" >> ${BASH_FILE}
		echo "export AZ_$SUB_IDX=${info_array[1]}" >> ${BASH_FILE}
		echo "export AZ_ID_$SUB_IDX=${info_array[2]}" >> ${BASH_FILE}
		((SUB_IDX++))
	done
	# private 子网
	EKS_PRI_SUBNET_LIST=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${EKS_VPC_ID}"  "Name=tag:Name,Values=*${NAME_PREFIX}-Private*" "Name=cidr-block,Values=*$(echo $EKS_VPC_CIDR | cut -d . -f 1).$(echo $EKS_VPC_CIDR | cut -d . -f 2).*" | jq '.Subnets | sort_by(.AvailabilityZone)' | jq '.[] .SubnetId')
	SUB_IDX=1
	for subnet in $EKS_PRI_SUBNET_LIST
	do
		echo "export PRI_SUBNET_$SUB_IDX=$subnet" >> ${BASH_FILE}
		((SUB_IDX++))
	done
	# pod 子网
	EKS_POD_SUBNET_LIST=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${EKS_VPC_ID}"  "Name=tag:Name,Values=*${NAME_PREFIX}-Pod*" "Name=cidr-block,Values=*100.66.*" | jq '.Subnets | sort_by(.AvailabilityZone)' | jq '.[] .SubnetId')
	SUB_IDX=1
	for subnet in $EKS_POD_SUBNET_LIST
	do
		echo "export POD_SUBNET_$SUB_IDX=$subnet" >> ${BASH_FILE}
		((SUB_IDX++))
	done
	# Additional security groups, 1
	export EKS_CLUSTER_SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$EKS_VPC_ID"  "Name=tag:Name,Values=*${NAME_PREFIX}-SG-control-plane*" | jq -r '.SecurityGroups[]|.GroupId')
	# Additional security groups, 2
	export EKS_ADDITIONAL_SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$EKS_VPC_ID"  "Name=tag:Name,Values=*${NAME_PREFIX}-SG-additional*" | jq -r '.SecurityGroups[]|.GroupId')
	# Custom network security groups
	export EKS_CUSTOMNETWORK_SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$EKS_VPC_ID"  "Name=tag:Name,Values=*${NAME_PREFIX}-SG-custom-network*" | jq -r '.SecurityGroups[]|.GroupId')
	# Share node security group
	export EKS_SHAREDNODE_SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$EKS_VPC_ID"  "Name=tag:Name,Values=*${NAME_PREFIX}-SG-shared-node*" | jq -r '.SecurityGroups[]|.GroupId')  
	# Extrenal security group
	export EKS_EXTERNAL_SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$EKS_VPC_ID"  "Name=tag:Name,Values=*${NAME_PREFIX}-SG-external*" | jq -r '.SecurityGroups[]|.GroupId')


  cat >> "$BASH_FILE" <<EOF
export ACCOUNT_ID=${ACCOUNT_ID} 
export AWS_REGION=${AWS_REGION}
export VPC_ID=$EKS_VPC_ID
export VPC_CIDR=$EKS_VPC_CIDR
export SG_CONTROL_PLANE=${EKS_CLUSTER_SG}
export SG_ADDITIONAL=${EKS_ADDITIONAL_SG}
export SG_CUSTOM_NETWORK=${EKS_CUSTOMNETWORK_SG}
export SG_SHARE_NODE=${EKS_SHAREDNODE_SG}
export SG_EXTERNAL=${EKS_EXTERNAL_SG}

# End adding by env.sh

EOF

fi

source ~/.bashrc
aws sts get-caller-identity