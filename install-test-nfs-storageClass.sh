#!/bin/bash

# Prepare script with correct switches
set +x
set -e
set -u

echo "================== Installing NFS Server (In POD) ================================="
kubectl apply -f https://gist.githubusercontent.com/matthewpalmer/0f213028473546b14fd75b7ebf801115/raw/2c557c70696ca4406db53c955471de1d2d808e9a/nfs-server.yaml

until [[ $(kubectl get pod nfs-server-pod -o=jsonpath='{.status.phase}') =~ "Running" ]]; do  echo "Waiting for NFS Server POD to become Running ";sleep 5; done

NFS_SERVER_IP=$(kubectl get svc nfs-service -o=custom-columns=IP:.spec.clusterIP --no-headers)
echo "========= NFS Server is installed (Running on IP : $NFS_SERVER_IP) ======================"
echo ""

echo "================== Installing Storage Class using Helm ==========================="
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=$NFS_SERVER_IP\
    --set nfs.path=/

until [[ $(kubectl get pods -l app=nfs-subdir-external-provisioner -o=jsonpath='{range .items[*]}{.status.phase}{end}') =~ "Running" ]]; do  echo "Waiting for nfs-subdir-external-provisioner POD to become Running ";sleep 5; done
echo " =============== Storage class is installed ======================================"
echo ""
echo " ================ Starting to test Storage class ================================="
rm -rf test-claim.yaml || echo "This can fail it's okay"
wget -q https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy/test-claim.yaml
sed -i -e "s/managed-nfs-storage/nfs-client/g" test-claim.yaml
kubectl apply -f test-claim.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy/test-pod.yaml
until [[ $(kubectl get pod test-pod -o=jsonpath='{.status.phase}') =~ "Succeeded" ]]; do  echo "Waiting for to Succeed ";sleep 5; done

echo "================= Test is Over =================================================="
echo ""

echo "================= Cleaning up Test POD and PVC ================================="
kubectl delete -f https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy/test-pod.yaml
kubectl delete -f test-claim.yaml
echo " ================ Cleanup finished =============================================="

