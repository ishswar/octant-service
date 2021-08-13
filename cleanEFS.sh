#!/bin/bash

set +x
set -e
set -u
set -o pipefail

######
### Clean EFS Script
### Input 1 : Creation token that was used while creating EFS
### Input 2 : AWS Region
### Input 3 : Name of EKS Cluster that this EFS is attached / used by
#####

EFS_CREATE_TOKEN=${1}
region=${2}
CLUSTER_NAME=${3}

echo "######### INPUTS ##############"
echo "### EFS_CREATE_TOKEN: ${EFS_CREATE_TOKEN}"
echo "### region: ${region}"
echo "### CLUSTER_NAME: ${CLUSTER_NAME}"
echo "###############################"

if [[ "$(aws efs describe-file-systems --creation-token $EFS_CREATE_TOKEN --region $region | jq -r .FileSystems[0].FileSystemId)" != null ]]; then
	  echo "Looks like old File system is present - we need to clean that first"
      FILE_SYSTEM_ID=$(aws efs describe-file-systems --creation-token $EFS_CREATE_TOKEN --region $region | jq -r .FileSystems[0].FileSystemId)
      MOUNT_IDS=$(aws efs describe-mount-targets --file-system-id $FILE_SYSTEM_ID --region $region | jq -r ".MountTargets[].MountTargetId")
      echo "First we need to delete mount points"
     for MOUNT_ID in ${MOUNT_IDS[@]}
      do
         echo "Deleting mount ID" $MOUNT_ID
         aws efs delete-mount-target --region $region --mount-target-id  $MOUNT_ID
      done

      until [ "$(aws efs describe-mount-targets --file-system-id $FILE_SYSTEM_ID --region $region | jq -r ".MountTargets[].MountTargetId" | wc -l)" -eq "0" ]; do echo "Waiting for mount id to be deleted"; sleep 5; done

      echo "Deleting $FILE_SYSTEM_ID now"
      echo "Now running command (aws efs delete-file-system --file-system-id $FILE_SYSTEM_ID --region $region) to delete EFS"
      aws efs delete-file-system --file-system-id $FILE_SYSTEM_ID --region $region
      until (aws efs describe-file-systems --creation-token $EFS_CREATE_TOKEN --region $region >/dev/null 2>/dev/null); do
      	  echo "Still deleteding EFS with ID [$FILE_SYSTEM_ID]"
      	  sleep 5
      done
      
      echo "Deleting SecurityGroup eks-$CLUSTER_NAME-efs-group"
      VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.resourcesVpcConfig.vpcId" --output text --region $region)
      MOUNT_TARGET_GROUP_NAME="eks-$CLUSTER_NAME-efs-group"
      MOUNT_TARGET_GROUP_DESC="NFS access to EFS from EKS worker nodes"
      MOUNT_TARGET_GROUP_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=$MOUNT_TARGET_GROUP_NAME Name=vpc-id,Values=$VPC_ID --region $region | jq --raw-output '.SecurityGroups[0].GroupId') || echo "this is fien"
      echo "About to delete SC : $MOUNT_TARGET_GROUP_ID"
      aws ec2 delete-security-group --group-id $MOUNT_TARGET_GROUP_ID --region $region || echo "this is fine too"

      echo "Done deleting EFS with ID [$FILE_SYSTEM_ID]"
else
   echo "OLD EFS does not exists - nothing to cleanup"
fi
