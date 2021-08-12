#!/bin/sh

# Prepare script with correct switches
set +x
set -e
set -u

CLUSTER_NAME=${1:-FAKE}
region=${2:-us-west-2}


echo "Input is : CLUSTER_NAME=${CLUSTER_NAME}"
echo "Input is : region=${region}"

VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query "cluster.resourcesVpcConfig.vpcId" --output text --region "$region")
echo "VPC ID for cluster $CLUSTER_NAME is [$VPC_ID]"
DNS_NAME=$(aws elbv2 describe-load-balancers --region "$region" | jq ".LoadBalancers[] | select(.VpcId==\"${VPC_ID}\")" | jq -r .DNSName)
export DNS_NAME=$DNS_NAME

echo "EKS DNS is : $DNS_NAME"