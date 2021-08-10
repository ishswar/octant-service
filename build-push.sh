#!/bin/bash

# Prepare script with correct switches
set +x
set -e
set -u
set -o pipefail

DOCKER_PASS=${1:-FAKE}
WF_TAG_PREFIX=${2:-wfc-8207.28}
RS_TAG_PREFIX=${3:-wfs-8207.28}
ETC_TAG_PREFIX=${4:-wfs-etc-8207.28}
CURRENT_RELEASE=${5:-beta}
vbuild=${6:-v28}

DOCKER_REPO=ibi2020/webfocus


echo "Input is : WF_TAG_PREFIX=${WF_TAG_PREFIX}"
echo "Input is : RS_TAG_PREFIX=${RS_TAG_PREFIX}"
echo "Input is : ETC_TAG_PREFIX=${ETC_TAG_PREFIX}"
echo "Input is : CURRENT_RELEASE=${CURRENT_RELEASE}"
echo "Input is : vbuild=${vbuild}"

RS_TAG=$RS_TAG_PREFIX-$CURRENT_RELEASE-$vbuild
WF_TAG=$WF_TAG_PREFIX-$CURRENT_RELEASE-$vbuild
ETC_TAG=$ETC_TAG_PREFIX-$CURRENT_RELEASE-$vbuild

echo "Using TAG : RS_TAG=${RS_TAG}"
echo "Using TAG : WF_TAG=${WF_TAG}"
echo "Using TAG : ETC_TAG=${ETC_TAG}"

docker login -u ibiuser -p $DOCKER_PASS

docker pull $DOCKER_REPO:$WF_TAG || {

  echo "Image [$DOCKER_REPO:$WF_TAG] is not there on Docker hub that means we need to build all 3 images"
  echo "============= Cleaning any local images if there any ====================="
  docker rmi $(docker images -q) || echo "Some images might not cleanup that's fine"
  echo "============== Done Cleaning local iamges ================================"
  echo "Now, building images"
  ./build-images.sh
  echo "============ TAGGING images ==================="
  docker tag $DOCKER_REPO:$RS_TAG_PREFIX $DOCKER_REPO:$RS_TAG
  docker tag $DOCKER_REPO:$ETC_TAG_PREFIX $DOCKER_REPO:$ETC_TAG
  docker tag $DOCKER_REPO:$WF_TAG_PREFIX $DOCKER_REPO:$WF_TAG
  echo "============ LISTING images =================="
  docker images  
  echo "============ PUSHING to Docker hub =========="
  docker push $DOCKER_REPO:$RS_TAG
  docker push $DOCKER_REPO:$ETC_TAG
  docker push $DOCKER_REPO:$WF_TAG
  echo "============ Done Pushing images to Docker hub ====="

}

echo "================= Running image validation ========================"
echo "======== Deleting local image [$DOCKER_REPO:$WF_TAG] and image [$DOCKER_REPO:$WF_TAG_PREFIX]"
echo ""
docker rmi $DOCKER_REPO:$WF_TAG
docker rmi $DOCKER_REPO:$WF_TAG_PREFIX
echo ""
echo "======== Pulling fresh copy"
docker pull $DOCKER_REPO:$WF_TAG
echo ""
echo "======== Reading lable Webfocusce_build from image"
echo ""
vbuild_inimage=$(docker inspect $DOCKER_REPO:$WF_TAG | jq .[].Config.Labels.Webfocusce_build -r)
vbuild_inimage=$(echo "$vbuild_inimage" | tr '[:upper:]' '[:lower:]')
echo "======== Comparing vbuild_inimage : [$vbuild_inimage] from vbuild that we have vbuild : [$vbuild] "
if [[ $vbuild_inimage =~ "$vbuild" ]];
   then
     echo "We found expected vbuild [$vbuild] in image lables we are good";
   else
    echo "We did not find what we were expecting in image lable ";
    echo "Printing image lables"
    docker inspect $DOCKER_REPO:$WF_TAG | jq .[].Config.Labels
    exit 123
fi
echo "=============== Done with image validation ====================="

echo ">>>>>>>>>>>>>>>> Images are pushed to Docker hub or they are already there <<<<<<<<<<<<<<<<<<<<<<<"