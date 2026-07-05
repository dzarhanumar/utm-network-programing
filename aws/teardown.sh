#!/bin/bash
# ============================================================
# Tears down everything created by setup-vpc-and-ec2.sh
# Run this AFTER you've taken your screenshots and finished testing,
# to make sure nothing keeps running (and billing) after submission.
#
# Usage: ./teardown.sh <VPC_ID> <SUBNET_ID> <SG_ID>
# (values were printed by setup-vpc-and-ec2.sh)
# ============================================================
set -e

REGION="ap-southeast-1"
VPC_ID=$1
SUBNET_ID=$2
SG_ID=$3

if [ -z "$VPC_ID" ] || [ -z "$SUBNET_ID" ] || [ -z "$SG_ID" ]; then
  echo "Usage: ./teardown.sh <VPC_ID> <SUBNET_ID> <SG_ID>"
  exit 1
fi

echo ">>> Terminating EC2 instances..."
INSTANCE_IDS=$(aws ec2 describe-instances --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text --region $REGION)
if [ -n "$INSTANCE_IDS" ]; then
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region $REGION > /dev/null
  aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS --region $REGION
  echo "Terminated: $INSTANCE_IDS"
fi

echo ">>> Deleting security group..."
aws ec2 delete-security-group --group-id $SG_ID --region $REGION || true

echo ">>> Finding and detaching Internet Gateway..."
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --query 'InternetGateways[0].InternetGatewayId' --output text --region $REGION)
if [ "$IGW_ID" != "None" ]; then
  aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION
  aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION
  echo "Deleted IGW: $IGW_ID"
fi

echo ">>> Deleting route table (non-main)..."
RTB_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=false" \
  --query 'RouteTables[0].RouteTableId' --output text --region $REGION)
if [ "$RTB_ID" != "None" ]; then
  aws ec2 delete-route-table --route-table-id $RTB_ID --region $REGION
  echo "Deleted route table: $RTB_ID"
fi

echo ">>> Deleting subnet..."
aws ec2 delete-subnet --subnet-id $SUBNET_ID --region $REGION

echo ">>> Deleting VPC..."
aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION

echo ">>> Cleanup done. Double-check the EC2 + VPC console to confirm nothing is left running."
