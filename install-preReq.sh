#!/bin/bash
{
set +x
set -e
set -u
set -o pipefail

printAndRunCommand() {
  limit=$(echo -n "$@" | wc -m)
  limit=$(($limit + 50))
  if [ "$limit" -gt "100" ]; then
    limit=100
  fi
  # shellcheck disable=SC2016
  printf '=%.0s' $(seq 1 $limit)
  echo ""
  echo "     Running command [$@]"
  printf '=%.0s' $(seq 1 $limit)
  echo ""
  "$@"
  printf '=%.0s' $(seq 1 $limit)
  echo ""
}

sudo apt-get -y update
#sudo apt-get -y upgrade
sudo apt-get -y install curl
# Check VXLAN exists
sudo apt-get install -y awscli

printAndRunCommand echo "Installing Docker"
#### Docker
# Install Docker CE
## Set up the repository:
### Install packages to allow apt to use a repository over HTTPS
sudo apt-get update && sudo apt-get install -y \
apt-transport-https ca-certificates curl software-properties-common gnupg2 net-tools jq nginx apache2-utils

sudo apt-get update
printAndRunCommand sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
printAndRunCommand sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo usermod -aG docker $USER
#newgrp docker


cat >daemon.json <<EOF
{
"exec-opts": ["native.cgroupdriver=systemd"],
"log-driver": "json-file",
"log-opts": {
"max-size": "100m"
},
"storage-driver": "overlay2"
}
EOF

sudo mv daemon.json /etc/docker/daemon.json


sudo mkdir -p /etc/systemd/system/docker.service.d

sudo systemctl daemon-reload
sudo systemctl restart docker



printAndRunCommand echo "End Installing Docker"

#### End Docker
printAndRunCommand echo "Installing kubeadm kubelet kubectl"
sudo apt-get install -y bash-completion
source /usr/share/bash-completion/bash_completion
sudo apt-get install -y apt-transport-https

sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
printAndRunCommand sudo apt-get install -y kubeadm=1.23.8-00 kubelet=1.23.8-00 kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "source <(kubeadm completion bash);source <(kubectl completion bash);alias nano='nano -cmET4';echo 'Hello k8s';source /usr/share/bash-completion/bash_completion" >>~/.bashrc
echo "source <(kubeadm completion bash);source <(kubectl completion bash);alias nano='nano -cmET4';echo 'Hello k8s';source /usr/share/bash-completion/bash_completion" >>/home/"${USER}"/.bashrc

printAndRunCommand echo "End Installing kubeadm kubelet kubectl"

printAndRunCommand echo "Installing helm and helmfile"

# Removed kubeadmin code - moved to helmsync script
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
sudo apt-get install apt-transport-https --yes
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
wget -q https://github.com/roboll/helmfile/releases/download/v0.139.9/helmfile_linux_amd64
chmod +x helmfile_linux_amd64
sudo mv helmfile_linux_amd64 /usr/sbin/helmfile

echo "export KUBE_EDITOR=nano" >>/home/${USER}/.bashrc

printAndRunCommand echo "Installing helm and helmfile"


# Check if all we need is installed now or not ..
# This should produce 4 lines output
if ( type kubectl >/dev/null 2>/dev/null ); then echo "==     ===> kubectl installed"; fi
if ( type helm >/dev/null 2>/dev/null ); then echo "==     ===> helm installed";  fi
if ( type helmfile >/dev/null 2>/dev/null ); then echo "==     ===> helmfile installed"; fi
if ( type kubeadm >/dev/null 2>/dev/null ); then echo "==     ===> kubeadm installed"; fi

cd ~
cat <<'EOF' >>/home/"${USER}"/done-withuserData.text

EOF
} 2>&1 | tee -a /home/"${USER}"/userdata-install.log