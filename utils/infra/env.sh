#!/bin/bash

source ~/.bashrc

# Tag to Env
# https://github.com/aws-samples/amazon-sagemaker-notebook-instance-lifecycle-config-samples/blob/master/scripts/set-env-variable/on-start.sh

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

# If CUSTOM_BASH exists, use it as default, otherwise fall back to $HOME/.bashrc
if [[ -f "$CUSTOM_BASH" ]]; then
  BASH_FILE="${1:-$CUSTOM_BASH}"
else
  BASH_FILE="${1:-$HOME/.bashrc}"
fi
NAME_PREFIX="SageVPC"

echo "==============================================="
echo "  Config envs ......"
echo "==============================================="
export AWS_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
test -n "$AWS_REGION" && echo AWS_REGION is "$AWS_REGION" || echo AWS_REGION is not set
aws configure set default.region "${AWS_REGION}"
aws configure get default.region
aws configure set region "$AWS_REGION"

# Get VPC information - Using proper naming convention from easy-eks-template-132.sh
export VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${NAME_PREFIX}" --query 'Vpcs[0].VpcId' --output text)
export VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --query 'Vpcs[0].{CidrBlock:CidrBlock}' --output text)

# 注意 filter 区分大小写
# Get public subnets with their availability zones - sorting by AZ
EKS_PUBAZ_INFO_LIST=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}"  "Name=tag:Name,Values=*${NAME_PREFIX}-PublicELB*" | jq '.Subnets | sort_by(.AvailabilityZone)' | jq '.[] | .SubnetId+","+.AvailabilityZone+","+.AvailabilityZoneId')

# Collect variables in separate arrays
PUB_SUBNETS=()
PRI_AZS=()
AZ_IDS=()
SUB_IDX=1

for pubazinfo in $EKS_PUBAZ_INFO_LIST
do
	export info_str=$(echo "$pubazinfo" | tr -d '"') # 去掉双引号
	IFS=',' read -ra info_array <<< "$info_str"
	PUB_SUBNETS+=("export PUB_SUBNET_$SUB_IDX=\"${info_array[0]}\"")
	PRI_AZS+=("export PRI_AZ_$SUB_IDX=\"${info_array[1]}\"")
	AZ_IDS+=("export AZ_ID_$SUB_IDX=\"${info_array[2]}\"")
	((SUB_IDX++))
done

# Get private subnets - sorting by AZ
PRI_SUBNET_LIST=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}"  "Name=tag:Name,Values=*${NAME_PREFIX}-Private*" "Name=cidr-block,Values=*$(echo $VPC_CIDR | cut -d . -f 1).$(echo $VPC_CIDR | cut -d . -f 2).*" | jq '.Subnets | sort_by(.AvailabilityZone)' | jq -r '.[] .SubnetId')
PRI_SUBNETS=()
SUB_IDX=1
for subnet in $PRI_SUBNET_LIST
do
	PRI_SUBNETS+=("export PRI_SUBNET_$SUB_IDX=\"$subnet\"")
	((SUB_IDX++))
done



# Get pod subnets - sorting by AZ
POD_SUBNET_LIST=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}"  "Name=tag:Name,Values=*${NAME_PREFIX}-Pod*" "Name=cidr-block,Values=*100.66.*" | jq '.Subnets | sort_by(.AvailabilityZone)' | jq -r '.[] .SubnetId')
POD_SUBNETS=()
SUB_IDX=1
for subnet in $POD_SUBNET_LIST
do
	POD_SUBNETS+=("export POD_SUBNET_$SUB_IDX=\"$subnet\"")
	((SUB_IDX++))
done

# Security groups - Using proper naming convention from easy-eks-template-132.sh
# Collect all security groups
declare -A SG_MAP

# Control plane security group
SG_MAP["SG_CONTROL_PLANE"]=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*${NAME_PREFIX}-SG-control-plane*" | jq -r '.SecurityGroups[]|.GroupId')

# Share node security group
SG_MAP["SG_SHARE_NODE"]=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*${NAME_PREFIX}-SG-shared-node*" | jq -r '.SecurityGroups[]|.GroupId')

# Custom network security groups
SG_MAP["SG_CUSTOM_NETWORK"]=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*${NAME_PREFIX}-SG-custom-network*" | jq -r '.SecurityGroups[]|.GroupId')

# Additional security groups
SG_MAP["SG_ADDITIONAL"]=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*${NAME_PREFIX}-SG-additional*" | jq -r '.SecurityGroups[]|.GroupId')

# External security group
SG_MAP["SG_EXTERNAL"]=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*${NAME_PREFIX}-SG-external*" | jq -r '.SecurityGroups[]|.GroupId')


# Write grouped variables to bash file
echo "" >> "${BASH_FILE}"  # Empty line for separation
echo "# Start adding by env.sh" | tee -a "${BASH_FILE}"

# First account and vpc info
echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a "${BASH_FILE}"
echo "export AWS_REGION=${AWS_REGION}" | tee -a "${BASH_FILE}"
echo "export VPC_ID=${VPC_ID}" | tee -a "${BASH_FILE}"
echo "export VPC_CIDR=${VPC_CIDR}" | tee -a "${BASH_FILE}"
echo "" >> "${BASH_FILE}"  # Empty line for separation

# Then all availability zones and AZ IDs
for az in "${PRI_AZS[@]}"; do
	echo "$az" >> "${BASH_FILE}"
done
echo "" >> "${BASH_FILE}"  # Empty line for separation

for az_id in "${AZ_IDS[@]}"; do
	echo "$az_id" >> "${BASH_FILE}"
done
echo "" >> "${BASH_FILE}"  # Empty line for separation

# Write all public subnets
for subnet in "${PUB_SUBNETS[@]}"; do
	echo "$subnet" >> "${BASH_FILE}"
done
echo "" >> "${BASH_FILE}"  # Empty line for separation

# Write all private subnets together
for subnet in "${PRI_SUBNETS[@]}"; do
	echo "$subnet" >> "${BASH_FILE}"
done
echo "" >> "${BASH_FILE}"  # Empty line for separation

# Write all pod subnets together
for subnet in "${POD_SUBNETS[@]}"; do
	echo "$subnet" >> "${BASH_FILE}"
done
echo "" >> "${BASH_FILE}"  # Empty line for separation

# Export security groups in organized order
for sg_name in "SG_CONTROL_PLANE" "SG_SHARE_NODE" "SG_CUSTOM_NETWORK" "SG_ADDITIONAL" "SG_EXTERNAL"; do
	if [ -n "${SG_MAP[$sg_name]}" ]; then
		echo "export $sg_name=\"${SG_MAP[$sg_name]}\"" >> "${BASH_FILE}"
	fi
done
echo "" >> "${BASH_FILE}"  # Empty line for separation


# Add end marker to the configuration
echo "# End adding by env.sh" >> "${BASH_FILE}"


source ~/.bashrc
aws sts get-caller-identity
