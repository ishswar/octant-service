#!/bin/sh

# Prepare script with correct switches
set +x
set -e
set -u

##########################################################################################################
### Helper script - it will use AWS CLI installed on machine
### Givne EKS cluster name and AWS region this script will find DNS of ELBV2 created for this cluster ####
### Output will be sotred in path $OUTPUT_FILE (i.e jenkins/terraform/dns-$CLUSTER_NAME.txt)
##########################################################################################################

CLUSTER_NAME=${1:-FAKE}
region=${2:-us-west-2}
OUTPUT_FILE=${3:-jenkins/terraform/dns-$CLUSTER_NAME.txt}


echo "Input is : CLUSTER_NAME=${CLUSTER_NAME}"
echo "Input is : region=${region}"
echo "Input is : OUTPUT_FILE=${OUTPUT_FILE}"

VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query "cluster.resourcesVpcConfig.vpcId" --output text --region "$region")
echo "VPC ID for cluster $CLUSTER_NAME is [$VPC_ID]"
# ELB
DNS_Name=$(aws elb describe-load-balancers --region "$region" | jq ".LoadBalancerDescriptions[] | select(.VPCId==\"$VPC_ID\")" | jq -r .DNSName)

# ELBV2
#DNS_Name=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" | jq ".LoadBalancers[] | select(.VpcId==\"$VPC_ID\")" | jq -r .DNSName)
#DNS_NAME=$(aws elbv2 describe-load-balancers --region "$region" --output json | jq ".LoadBalancers[] | select(.VpcId==\"${VPC_ID}\")" | jq -r .DNSName)

echo "Cleaning up DNS_NAME value $DNS_NAME"
DNS_NAME=$(echo "$DNS_NAME"|tr '\n' ' ') # Remove new line 
DNS_NAME=${DNS_NAME%% } # Remove trailing spaces 
echo "After Cleaning up DNS_NAME value [$DNS_NAME]"
echo "Writing DNS Entry into file"
echo "$DNS_NAME" > "$OUTPUT_FILE"