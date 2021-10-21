# Create VPC and Subnets 



echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt-get install apt-transport-https ca-certificates gnupg
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
sudo apt-get update && sudo apt-get install google-cloud-sdk -y 
gcloud version

gcloud auth activate-service-account --key-file g-key.json
gcloud projects list
gcloud config set project webfocus-devops
gcloud container clusters list
gcloud container clusters describe pshah-wfc --region us-west1-c
```
gcloud compute networks create webfocus-vpc --project=webfocus-pshah --description=VPC\ For\ Webfocus --subnet-mode=custom --mtu=1460 --bgp-routing-mode=regional

gcloud compute networks subnets create webfocus-pub1 --project=webfocus-pshah --description=Public\ Subnet\ One --range=192.168.0.0/18 --network=webfocus-vpc --region=us-west1

gcloud compute networks subnets create webfocus-pub2 --project=webfocus-pshah --range=192.168.64.0/18 --network=webfocus-vpc --region=us-west1
```

gcloud compute firewall-rules create out-of-gcp --network webfocus-vpc --allow tcp,udp,icmp --source-ranges 73.93.49.100

gcloud compute firewall-rules create in-gcp --network webfocus-vpc --allow tcp:22,tcp:3389,icmp



#gcloud container clusters create pshah-wfc --release-channel rapid --disk-size 200 --num-nodes 3 --machine-type e2-highcpu-8 --no-enable-cloud-logging --no-enable-cloud-monitoring --zone us-west1-c --addons=GcpFilestoreCsiDriver

gcloud container clusters create pshah-wfc --disk-size 200 --num-nodes 3 --machine-type e2-highcpu-8 --no-enable-cloud-logging --no-enable-cloud-monitoring --zone us-west1-c

gcloud container clusters get-credentials pshah-wfc --zone us-west1-c



FS=pshah-wfc-fs
PROJECT=webfocus-devops
ZONE=us-west1-c
gcloud filestore instances create ${FS} \
  --project=webfocus-devops \
  --zone=us-west1-c \
  --tier=STANDARD \
  --file-share=name="volumes",capacity=1TB \
  --network=name="default"

FS=pshah-wfc-fs
PROJECT=webfocus-devops
ZONE=us-west1-c  
FSADDR=$(gcloud filestore instances describe ${FS} \
  --project=${PROJECT} \
  --zone=${ZONE} \
  --format="value(networks.ipAddresses[0])")  
  
  
echo "========= NFS Server is installed (Running on IP : $FSADDR) ======================"
echo ""

echo "================== Installing Storage Class using Helm ==========================="
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=$FSADDR\
    --set nfs.path=/volumes

until [[ $(kubectl get pods -l app=nfs-subdir-external-provisioner -o=jsonpath='{range .items[*]}{.status.phase}{end}') =~ "Running" ]]; do  echo "Waiting for nfs-subdir-external-provisioner POD to become Running ";sleep 5; done
echo " =============== Storage class is installed ======================================"
echo ""
echo " ================ Starting to test Storage class ================================="
rm -rf test-claim.yaml || echo "This can fail it's okay"
#wget -q https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy/test-claim.yaml

curl https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy/test-claim.yaml -O



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
kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' || echo "This might fail it's okay"
echo ""
kubectl get sc 
echo "###################################################################################"
echo " ================ Script done ================================================="
echo "###################################################################################"  

export PLATFORM_NAME=webfocus
export RS_TAG=wfs-8207.28-beta-v34
export WF_TAG=wfc-8207.28-beta-v34
export ETC_TAG=wfs-etc-8207.28-beta-v34


kubectl create ns nginx-ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx -n nginx-ingress 
kubectl get deployment nginx-ingress-ingress-nginx-controller  -n nginx-ingress 
kubectl get service nginx-ingress-ingress-nginx-controller  -n nginx-ingress
    until (kubectl get svc -n nginx-ingress nginx-ingress-ingress-nginx-controller -o json | jq .status.loadBalancer.ingress[].ip -r >/dev/null 2>/dev/null); do
      echo "Waiting for Ingress Controller to get DNS Name assigned "
      sleep 5
    done


gcloud filestore instances list
gcloud container clusters list

edit charts/edaserver/templates/statefulset.yaml for probes 



gcloud sql instances create wfc-instance --database-version=POSTGRES_13 --cpu=4 --memory=16GiB --zone=us-west1-c --root-password=webfocus \
 --storage-type=SSD --assign-ip --no-backup
gcloud sql instances describe wfc-instance --format json | jq .settings.ipConfiguration
CLUSTER_EGRESS_IP=$(kubectl exec -n webfocus edaserver-0 -- curl -s http://ifconfig.me)
echo "Adding $CLUSTER_EGRESS_IP to Gloud SQL Server"
gcloud sql instances patch wfc-instance --authorized-networks 73.93.49.100/32,$CLUSTER_EGRESS_IP/32 -q
gcloud sql instances describe wfc-instance --format json | jq .settings.ipConfiguration
#gcloud sql instances delete wfc-instance

gcloud sql instances describe pshah-wfc --format json | jq .settings.ipConfiguration
CLUSTER_EGRESS_IP=$(kubectl exec -n webfocus edaserver-0 -- curl -s http://ifconfig.me)
echo "Adding $CLUSTER_EGRESS_IP to Gloud SQL Server"
gcloud sql instances patch pshah-wfc --authorized-networks 73.93.49.100/32,$CLUSTER_EGRESS_IP/32 -q
gcloud sql instances describe pshah-wfc --format json | jq .settings.ipConfiguration

# Google cloud DB : jdbc:postgresql://34.83.140.157:5432/postgres?currentSchema=public ( postgres / webfocus )

#helmfile -e aws --state-values-set swego.enabled=true destroy
#helmfile  destroy
#gcloud container clusters delete pshah-wfc --region us-west1-c
#gcloud filestore instances delete pshah-wfc-fs --zone us-west1-c  







    INGRESS_NAME=appserver
    PLATFORM_NAME=webfocus
    envName=pshah
    DNS_IP=$(kubectl get svc -n nginx-ingress nginx-ingress-ingress-nginx-controller -o json | jq .status.loadBalancer.ingress[].ip -r)
    DNS_Name=$DNS_IP.nip.io

    echo "Using DNS Name $DNS_Name for ingress [$INGRESS_NAME]"

    kubectl patch ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME --type='json' -p='[{"op": "replace", "path": "/metadata/annotations/nginx.ingress.kubernetes.io~1force-ssl-redirect", "value":"false"}]'
    kubectl patch ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME --type='json' -p='[{"op": "add", "path": "/metadata/annotations/nginx.ingress.kubernetes.io~1ssl-redirect", "value":"false"}]'

    # Changed on request of Shu
    #kubectl patch ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME --type='json' -p='[{"op": "add", "path": "/metadata/annotations/nginx.ingress.kubernetes.io~1session-cookie-path", "value":"\"/\""}]'
    kubectl patch ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME --type='json' -p='[{"op": "add", "path": "/metadata/annotations/nginx.ingress.kubernetes.io~1session-cookie-path", "value":"/"}]'
    # shellcheck disable=SC2016
    kubectl patch ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME --type='json' -p="[{'op': 'replace', 'path': '/spec/rules/0/host', 'value':"$DNS_Name"}]"
    kubectl patch ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME --type='json' -p="[{'op': 'replace', 'path': '/spec/rules/0/http/paths/0/path', 'value':"/\(.*\)"}]"
    kubectl patch ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME --type='json' -p="[{'op': 'replace', 'path': '/spec/rules/1/host', 'value':"$DNS_Name"}]"

    kubectl patch ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME --type='json' -p="[{'op': 'replace', 'path': '/spec/rules/2/host', 'value':"$envName-wfc.k8sguy.xyz"}]"
    kubectl patch ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME --type='json' -p="[{'op': 'replace', 'path': '/spec/rules/3/host', 'value':"$envName-wfc.k8sguy.xyz"}]"
    # shellcheck disable=SC2016
    kubectl patch ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME --type='json' -p="[{'op': 'replace', 'path': '/spec/tls/0/hosts/0', 'value':"$DNS_Name"}]"

    if [[ "$DO_DNS_UPDATE" =~ "Yes" ]]; then
      {
    echo "Updating Ingress with Cert for *.k8sguy.xyz"
    # Public wildcard cert for k8sguy.xyz
    kubectl create -n $PLATFORM_NAME secret tls tls-secret --key /home/ubuntu/addtional_files/certs/privkey.pem --cert /home/ubuntu/addtional_files/certs/fullchain.pem
    #kubectl patch ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME --type='json' -p="[{'op': 'add', 'path': '/spec/tls/0/hosts/secretName', 'value':'tls-secret'}]"
    kubectl patch ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME --type='json' -p="[{'op': 'add', 'path': '/spec/tls/1', 'value':{"hosts": ["$envName-wfc.k8sguy.xyz"],"secretName": "tls-secret"}}]"
    kubectl patch ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME --type='json' -p='[{"op": "replace", "path": "/metadata/annotations/nginx.ingress.kubernetes.io~1force-ssl-redirect", "value":"true"}]'
    kubectl patch ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME --type='json' -p='[{"op": "add", "path": "/metadata/annotations/nginx.ingress.kubernetes.io~1ssl-redirect", "value":"true"}]'
    }
    fi
    # shellcheck disable=SC2016
    kubectl patch ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME --type='json' -p='[{"op": "add", "path": "/metadata/annotations/nginx.ingress.kubernetes.io~1rewrite-target", "value":"/$1"}]'


    #openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=eks1.k8sguy.xyz/O=eks1.k8sguy.xyz"
    #kubectl create -n webfocus secret tls tls-secret --key tls.key --cert tls.crt
    until (kubectl get ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME -o json | jq .status.loadBalancer.ingress[].hostname >/dev/null 2>/dev/null); do
      echo "Waiting for Ingress to get DNS Name assigned "
      sleep 5
    done
    INGRESS_DNS_NAME=$(kubectl get ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME -o json | jq .status.loadBalancer.ingress[].hostname -r)
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~ YAML ~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    kubectl get ingresses.networking.k8s.io $INGRESS_NAME -n $PLATFORM_NAME -o yaml
    echo "~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~~~~~~ ~~~~~~~~~~~~~~~~~~~~~~"
    echo "Ingress's Public DNS is http://$INGRESS_DNS_NAME"
    echo ""
    echo "################## Done setting up Ingress ##################"