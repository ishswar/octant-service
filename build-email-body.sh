#!/bin/bash

# Prepare script with correct switches
set +x
set -e
set -u

echo "Shell is $SHELL & useEKS is $useEKS , envBUILD_STATUS is ${JOB_NAME} - BUILD_DURATION ${BUILD_DURATION} BUILD_RESLUT ${BUILD_RESLUT}"
rm -rf email.html || echo "email template is not there - that's fine "
curl --silent -o email.html https://raw.githubusercontent.com/ishswar/octant-service/master/email.html



sed -i -e "s/JOB_STATUS/${BUILD_RESLUT}/g" email.html
sed -i -e "s/JOB_DURATION/${BUILD_DURATION}/g" email.html
sed -i -e "s!JOB_URL!$BUILD_URL!g" email.html

sed -i -e "s!JOB_ID!$BUILD_NUMBER!g" email.html
sed -i -e "s!PARAMTER_VERSION!$product_version!g" email.html
sed -i -e "s!SWEGO_URL!$SWEGO_URL!g" email.html


sed -i -e "s!PUBLIC_IP!$PUBLIC_IP!g" email.html
sed -i -e "s!OCTANT_URL!http://${PUBLIC_IP}:$OCTANT_PORT!g" email.html
sed -i -e "s!PARAMTER_ENVIRONMENT!$environment!g" email.html
sed -i -e "s!PARAMTER_AUTOAPPROVE!$autoApprove!g" email.html
sed -i -e "s!PARAMTER_ACTION!$action!g" email.html
sed -i -e "s!PARAMTER_USELOCALIMAGES!$useLocalImages!g" email.html
sed -i -e "s!PARAMTER_CONFIGURE!$configure!g" email.html
sed -i -e "s!PARAMTER_REUSEEKSCLUSTER!$reUseEKSCluster!g" email.html
sed -i -e "s!PARAMTER_TARVERSION!<a href="http://reldist.tibco.com/package/webfocusce/1.0.0/$tarversion">$tarversion</a>!g" email.html
sed -i -e "s!PARAMTER_EC2_INSTANCE_TYPE!$bastion_instance_type!g" email.html
sed -i -e "s!PARAMTER_EC2_REGION!$region!g" email.html
sed -i -e "s!USER_NAME!$environment!g" email.html
CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
sed -i -e "s!REPORT_DATE!$CURRENT_DATE!g" email.html
WEBFOUS_URL=$(echo "$WEBFOUS_URL"|tr '\n' ' ')
sed -i -e "s!WEBFOCUS_URL!$WEBFOUS_URL!g" email.html
if [ "$useEKS" = "Yes" ]; then
 sed -i -e "s/CLUSTER_TYPE/EKS/g" email.html
else
 sed -i -e "s/CLUSTER_TYPE/LOCAL Cluster/g" email.html
fi

TEMP_FOLDER=$(mktemp -d)
BUILD_DATA_FILE="$TEMP_FOLDER/build-info.txt"
DOCKER_INFO_FILE="$TEMP_FOLDER/docker-images.txt"
CONTAINER_IMAGES_IN_USE="$TEMP_FOLDER/container-images-in-use.txt"

aws s3 ls s3://ibi-devops/Jenkins/"$environment/" || { echo "S3 ls failed "; }

if ( aws s3 ls s3://ibi-devops/Jenkins/"$environment"/$(basename $BUILD_DATA_FILE) >/dev/null 2>/dev/null);then
    echo "$BUILD_DATA_FILE exists - let's copy it to S3"
    aws s3 cp s3://ibi-devops/Jenkins/"$environment"/$(basename $BUILD_DATA_FILE) $BUILD_DATA_FILE
else
    echo "$(basename $BUILD_DATA_FILE) doesn't exist - we will not copy it to s3"
fi

DATA="$(cat $BUILD_DATA_FILE)"
echo "Creating Escapte data"
ESCAPED_DATA="$(echo "${DATA}" | sed ':a;N;$!ba;s!\n!\\n!g' | sed 's!\$!\\$!g')"
cat email.html | sed 's!K8S_OUTPUT!'"${ESCAPED_DATA}"'!' > email-new.html

mv email-new.html email.html

if ( aws s3 ls s3://ibi-devops/Jenkins/"$environment"/$(basename $CONTAINER_IMAGES_IN_USE) >/dev/null 2>/dev/null);then
    echo "$CONTAINER_IMAGES_IN_USE exists - let's copy it to S3"
    aws s3 cp s3://ibi-devops/Jenkins/"$environment"/$(basename $CONTAINER_IMAGES_IN_USE) $CONTAINER_IMAGES_IN_USE
else
    echo "$(basename $CONTAINER_IMAGES_IN_USE) doesn't exist - we will not copy it to s3"
fi

DATA="$(cat $CONTAINER_IMAGES_IN_USE)"
echo "Creating Escapte data"
ESCAPED_DATA="$(echo "${DATA}" | sed ':a;N;$!ba;s!\n!\\n!g' | sed 's!\$!\\$!g')"
cat email.html | sed 's!IMAGES_IN_USE!'"${ESCAPED_DATA}"'!' > email-new.html

mv email-new.html email.html

if ( aws s3 ls s3://ibi-devops/Jenkins/"$environment"/$(basename $DOCKER_INFO_FILE) >/dev/null 2>/dev/null);then
    echo "$DOCKER_INFO_FILE exists - let's copy it to S3"
    aws s3 cp s3://ibi-devops/Jenkins/"$environment"/$(basename $DOCKER_INFO_FILE) $DOCKER_INFO_FILE
    sed -i -e "s/PUSHED_REUSE/PUSHED/g" email.html
    
else
    echo "$(basename $DOCKER_INFO_FILE) doesn't exist - we will not copy it to s3"
    sed -i -e "s/PUSHED_REUSE/REUSED (Docker hub)/g" email.html
fi

DATA="$(cat $DOCKER_INFO_FILE)"
echo "Creating Escapte data"
ESCAPED_DATA="$(echo "${DATA}" | sed ':a;N;$!ba;s!\n!\\n!g' | sed 's!\$!\\$!g')"
cat email.html | sed 's!DOCKER_IMAGES_OUTPUT!'"${ESCAPED_DATA}"'!' > email-new.html

mv email-new.html email.html

rm -rf $TEMP_FOLDER