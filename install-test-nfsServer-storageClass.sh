#!/bin/bash

# Prepare script with correct switches
set -x
set -e
set -u

echo "================== Installing NFS Server (In Machine) ================================="
sudo apt-get install nfs-kernel-server -y
sudo systemctl enable --now nfs-server
sudo mkdir -p /srv/data
sudo chown -R nobody:nogroup /srv/data
sudo chmod 777 /srv/data
echo "/srv/data *(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
sudo exportfs -a
sudo systemctl status nfs-server --no-pager

NFS_SERVER_IP=$(hostname -I | cut -d ' ' -f1)
echo "========= NFS Server is installed (Running on IP : $NFS_SERVER_IP) ======================"
echo ""

echo "================== Installing Storage Class using Helm ==========================="
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=$NFS_SERVER_IP\
    --set nfs.path=/srv/data

until [[ $(kubectl get pods -l app=nfs-subdir-external-provisioner -o=jsonpath='{range .items[*]}{.status.phase}{end}') =~ "Running" ]]; do  echo "Waiting for nfs-subdir-external-provisioner POD to become Running ";sleep 5; done
echo " =============== Storage class is installed ======================================"
echo ""
echo " ================ Starting to test Storage class ================================="
rm -rf test-claim.yaml || echo "This can fail it's okay"
wget -q https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy/test-claim.yaml
sed -i -e "s/managed-nfs-storage/nfs-client/g" test-claim.yaml
kubectl apply -f test-claim.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy/test-pod.yaml
until [[ $(kubectl get pod test-pod -o=jsonpath='{.status.phase}') =~ "Succeeded" ]]; do  echo "Waiting for test-pod to Succeed ";sleep 5; done

echo "================= Test is Over =================================================="
kubectl get pods,pvc,pv
echo ""

echo "================= Cleaning up Test POD and PVC ================================="
kubectl delete -f https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy/test-pod.yaml
kubectl delete -f test-claim.yaml
echo " ================ Cleanup finished =============================================="
kubectl get sc
echo " ================ Making nfs-client as defalut storageclass ====================="
kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' || echo "This might fail it's okay"
kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' || echo "This might fail it's okay"
echo ""
kubectl get sc 
echo "###################################################################################"
echo " ================ Script done ================================================="
echo "###################################################################################"

