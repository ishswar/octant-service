#!/bin/bash

set +x
set -e
set -u
set -o pipefail

CLUSTER_NAME=${1:-ramakuma}
EFS_CREATE_TOKEN=$CLUSTER_NAME-EFS
ACCOUNT_ID=837550156338
region=${2:-us-west-2}

echo "######### INPUTS ##############"
echo "### CLUSTER_NAME: ${CLUSTER_NAME}"
echo "### region: ${region}"
echo "#############################"

echo "~~~~~~~~~~~~~~~~~ INPUTS ~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "CLUSTER_NAME: $CLUSTER_NAME"
echo "region: $region"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

echo "======================================================================================"
echo "================================  Creating IAM Policy   =============================="
echo "======================================================================================"
curl --silent -o iam-policy-example.json https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/v1.3.2/docs/iam-policy-example.json

aws iam create-policy --policy-name AmazonEKS_EFS_CSI_Driver_Policy --policy-document file://iam-policy-example.json || echo "Looks like IAM Policy AmazonEKS_EFS_CSI_Driver_Policy already there"

eksctl utils associate-iam-oidc-provider --region=$region --cluster=$CLUSTER_NAME --approve

eksctl create iamserviceaccount \
    --name efs-csi-controller-sa \
    --namespace kube-system \
    --cluster $CLUSTER_NAME \
    --attach-policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AmazonEKS_EFS_CSI_Driver_Policy \
    --approve \
    --override-existing-serviceaccounts \
    --region $region

echo "======================================================================================"
echo "======================  Adding Helm Chart : aws-efs-csi  =============================="
echo "======================================================================================"

helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/

helm repo update

helm uninstall aws-efs-csi-driver -n kube-system || echo "Nothing to delete so moving on"

helm upgrade -i aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
    --namespace kube-system \
    --set image.repository=602401143452.dkr.ecr.us-west-2.amazonaws.com/eks/aws-efs-csi-driver \
    --set controller.serviceAccount.create=false \
    --set controller.serviceAccount.name=efs-csi-controller-sa

timeout 5m bash -c  'until [[ "$(kubectl get pod -n kube-system -l "app.kubernetes.io/name=aws-efs-csi-driver,app.kubernetes.io/instance=aws-efs-csi-driver" -o jsonpath={..status.phase} | grep "Running" | wc -w)" -eq "4" ]]; do echo "Starting CSI Driver"; sleep 5; done'

echo "======================================================================================"
echo "================================  Creating EFS  ======================================"
echo "======================================================================================"

curl --silent -o cleanEFS.sh https://raw.githubusercontent.com/ishswar/octant-service/master/cleanEFS.sh
chmod +x cleanEFS.sh 

./cleanEFS.sh $EFS_CREATE_TOKEN $region $CLUSTER_NAME

echo "======================================================================================"
echo "============================  Creating new EFS Now  =================================="
echo "======================================================================================"

VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.resourcesVpcConfig.vpcId" --output text --region $region)
CIDR_BLOCK=$(aws ec2 describe-vpcs --vpc-ids $VPC_ID --query "Vpcs[].CidrBlock" --output text --region $region)

MOUNT_TARGET_GROUP_NAME="eks-$CLUSTER_NAME-efs-group"
MOUNT_TARGET_GROUP_DESC="NFS access to EFS from EKS worker nodes"
MOUNT_TARGET_GROUP_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=$MOUNT_TARGET_GROUP_NAME Name=vpc-id,Values=$VPC_ID --region $region | jq --raw-output '.SecurityGroups[0].GroupId') || echo "this is fien"
aws ec2 delete-security-group --group-id $MOUNT_TARGET_GROUP_ID --region $region || echo "this is fine too"
MOUNT_TARGET_GROUP_ID=$(aws ec2 create-security-group --group-name $MOUNT_TARGET_GROUP_NAME --description "$MOUNT_TARGET_GROUP_DESC" --vpc-id $VPC_ID --region $region | jq --raw-output '.GroupId')

aws ec2 authorize-security-group-ingress --region $region --group-id $MOUNT_TARGET_GROUP_ID --protocol tcp --port 2049 --cidr $CIDR_BLOCK

FILE_SYSTEM_ID=$(aws efs create-file-system --creation-token $CLUSTER_NAME-EFS --region $region -tags Key=Name,Value="EFS For EKS $CLUSTER_NAME" | jq --raw-output '.FileSystemId')

echo "File system is $FILE_SYSTEM_ID is creted"

aws efs --region $region describe-file-systems --file-system-id $FILE_SYSTEM_ID

aws efs --region $region describe-file-systems --file-system-id $FILE_SYSTEM_ID | jq -r .FileSystems[0].LifeCycleState

until [[ $(aws efs --region $region describe-file-systems --file-system-id $FILE_SYSTEM_ID | jq -r .FileSystems[0].LifeCycleState) =~ "available" ]]; do  echo "Waiting for File system $FILE_SYSTEM_ID to be available ";sleep 5; done

TAG1=tag:alpha.eksctl.io/cluster-name
TAG2=tag:kubernetes.io/role/elb
subnets=($(aws ec2 describe-subnets --region $region --filters "Name=$TAG1,Values=$CLUSTER_NAME" "Name=$TAG2,Values=1" | jq --raw-output '.Subnets[].SubnetId'))
for subnet in ${subnets[@]}
do
    echo "creating mount target in " $subnet
    aws efs create-mount-target --region $region --file-system-id $FILE_SYSTEM_ID --subnet-id $subnet --security-groups $MOUNT_TARGET_GROUP_ID || echo "Sometime this might fail"
done

until [ "$(aws efs describe-mount-targets --region $region --file-system-id $FILE_SYSTEM_ID | jq --raw-output '.MountTargets[].LifeCycleState' | grep available | wc -l)" -eq "3" ]; do echo "Waiting for mount targets to be available"; sleep 5; done


echo "************************** EFS with id [$FILE_SYSTEM_ID] is ready to be used by EKS *******************************"

echo "======================================================================================"
echo "===========================  Creating Storage class =================================="
echo "======================================================================================"

curl --silent -o storageclass.yaml https://raw.githubusercontent.com/ishswar/octant-service/master/storageclass.yaml
# Tell storage class to use our new EFS 
sed -i -e "s/FILE_SYSTEM_ID/$FILE_SYSTEM_ID/g" storageclass.yaml

kubectl delete -f storageclass.yaml --force || echo "Nothing to delete so moving on"

kubectl apply -f storageclass.yaml

kubectl patch storageclass efs-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

echo "======================================================================================"
echo "============================  Testing Storage class =================================="
echo "======================================================================================"

curl --silent -o pod.yaml https://raw.githubusercontent.com/ishswar/octant-service/master/pod.yaml

kubectl apply -f pod.yaml --force || echo "Nothing to delete so moving on"

kubectl apply -f pod.yaml



timeout 5m bash -c 'until [[ $(kubectl get pod efs-app -o jsonpath={..status.phase}) =~ "Running" ]]; do  echo "Waiting for Pod to go in Running state ";sleep 5; done'
if [[ $(kubectl get pod efs-app -o jsonpath={..status.phase}) =~ "Running" ]]; then
 {
	echo "#########################################"
	echo "################# SUCCESS ###############"
	echo "#########################################"
 }
else 
 {
 	echo "Test POD is not running need to invastigate"
 	exit 123
 }
fi

echo "======================================================================================"
echo "====================  PVC and PV Storage in cluster =================================="
echo "======================================================================================"
kubectl get all ; kubectl get pvc ; kubectl get pv


echo "======================================================================================"
echo "====================  Cleaning test POD and PVC from cluster ========================="
echo "======================================================================================"

kubectl delete -f pod.yaml --force --grace-period=0

