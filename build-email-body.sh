#!/bin/bash

# Prepare script with correct switches
set +x
set -e
set -u

echo "Shell is $SHELL & useEKS is $useEKS , envBUILD_STATUS is ${JOB_NAME} - BUILD_DURATION ${BUILD_DURATION} BUILD_RESLUT ${BUILD_RESLUT}"
rm -rf email.html || echo "email template is not there - that's fine "
curl --silent -o email.html https://raw.githubusercontent.com/ishswar/octant-service/master/email.html



## Stuff removed

TEMP_FOLDER=$(mktemp -d)
BUILD_DATA_FILE="$TEMP_FOLDER/build-info.txt"
DOCKER_INFO_FILE="$TEMP_FOLDER/docker-images.txt"

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

if ( aws s3 ls s3://ibi-devops/Jenkins/"$environment"/$(basename $DOCKER_INFO_FILE) >/dev/null 2>/dev/null);then
    echo "$DOCKER_INFO_FILE exists - let's copy it to S3"
    aws s3 cp s3://ibi-devops/Jenkins/"$environment"/$(basename $DOCKER_INFO_FILE) $DOCKER_INFO_FILE
else
    echo "$(basename $DOCKER_INFO_FILE) doesn't exist - we will not copy it to s3"
fi

DATA="$(cat $DOCKER_INFO_FILE)"
echo "Creating Escapte data"
ESCAPED_DATA="$(echo "${DATA}" | sed ':a;N;$!ba;s!\n!\\n!g' | sed 's!\$!\\$!g')"
cat email.html | sed 's!DOCKER_IMAGES_OUTPUT!'"${ESCAPED_DATA}"'!' > email-new.html

mv email-new.html email.html

rm -rf $TEMP_FOLDER