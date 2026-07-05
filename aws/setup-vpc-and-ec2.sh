#!/bin/bash
# ============================================================
# Builds the AWS infrastructure for the SECR3253 project:
# 1 VPC -> 1 public subnet -> Internet Gateway -> Route Table
# -> Security Group -> 3 EC2 instances (ansible-control, router1, router2)
#
# Prerequisite: `aws configure` already run with your AWS Free Tier
# account's Access Key / Secret Key.
# ============================================================
set -e

REGION="ap-southeast-1"       # Singapore - closest region to Malaysia
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"
AZ="ap-southeast-1a"
KEY_NAME="network-automation-key"
INSTANCE_TYPE="t3.micro"       # Free tier eligible on both legacy and new AWS accounts

echo ">>> Creating VPC..."
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --region $REGION --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=network-automation-vpc
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support "{\"Value\":true}"
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames "{\"Value\":true}"
echo "VPC_ID=$VPC_ID"

echo ">>> Creating public subnet..."
SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_CIDR --availability-zone $AZ --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $SUBNET_ID --tags Key=Name,Value=network-automation-subnet
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch
echo "SUBNET_ID=$SUBNET_ID"

echo ">>> Creating and attaching Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=network-automation-igw
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
echo "IGW_ID=$IGW_ID"

echo ">>> Creating route table with default route to IGW..."
RTB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources $RTB_ID --tags Key=Name,Value=network-automation-rtb
aws ec2 create-route --route-table-id $RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID > /dev/null
aws ec2 associate-route-table --subnet-id $SUBNET_ID --route-table-id $RTB_ID > /dev/null
echo "RTB_ID=$RTB_ID"

echo ">>> Creating security group (SSH from your IP + between instances)..."
SG_ID=$(aws ec2 create-security-group --group-name network-automation-sg --description "SSH access" --vpc-id $VPC_ID --query 'GroupId' --output text)
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr ${MY_IP}/32 > /dev/null
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --source-group $SG_ID > /dev/null
echo "SG_ID=$SG_ID (your IP allowed: $MY_IP)"

echo ">>> Creating key pair..."
aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text --region $REGION > ${KEY_NAME}.pem
chmod 400 ${KEY_NAME}.pem
echo "Saved private key to ${KEY_NAME}.pem"

echo ">>> Finding latest Ubuntu 22.04 AMI..."
AMI_ID=$(aws ec2 describe-images --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text --region $REGION)
echo "AMI_ID=$AMI_ID"

echo ">>> Launching 3 EC2 instances..."
for NAME in ansible-control router1 router2; do
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --subnet-id $SUBNET_ID \
    --associate-public-ip-address \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NAME}]" \
    --query 'Instances[0].InstanceId' --output text \
    --region $REGION)
  echo "$NAME -> $INSTANCE_ID"
done

echo ""
echo "============================================================"
echo "Done. Save these values - you'll need them for the next step:"
echo "VPC_ID=$VPC_ID"
echo "SUBNET_ID=$SUBNET_ID"
echo "SG_ID=$SG_ID"
echo "Key file: ${KEY_NAME}.pem"
echo ""
echo "Wait ~1 minute for instances to boot, then run:"
echo "aws ec2 describe-instances --filters \"Name=tag:Name,Values=ansible-control,router1,router2\" \\"
echo "  --query 'Reservations[].Instances[].[Tags[?Key==\`Name\`]|[0].Value,PublicIpAddress,PrivateIpAddress]' \\"
echo "  --output table --region $REGION"
echo "============================================================"
