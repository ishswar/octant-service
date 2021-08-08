#!/bin/bash

set +x
set -e
set -u
set -o pipefail

EFS_CREATE_TOKEN=${1}
region=${2}

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
      echo "Done deleting EFS with ID [$FILE_SYSTEM_ID]"
else
   echo "OLD EFS does not exists - nothing to cleanup"
fi
