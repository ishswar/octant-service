
# Introduction 

In this demo we will start with multi tear web app, and see how we can deploy them to Kubernetes 

- Using just YAML/Manfiests 
- Converting them to individual Helm charts 
- Creating multiple values file to support different deployment requirement 
- Running same set of Helm charts using Helmfile 
- Utilizing Helmfile to support different deployment requirements 

# Sample app

Sample deployment files that we will use in this demo come from Repo [https://github.com/dockersamples/example-voting-app](https://github.com/dockersamples/example-voting-app) - thanks a bunch to [Bret Fisher](https://github.com/BretFisher)

# Pre-req 

We expect you have running kubernetes and have kubectl configured and pointing to correct context so that it can connect to that cluster.
You will also need Helm and helmfile tool installed ( steps for helmfile install are given ) 


# Playground.

If you don't have access to running kubernetes and want to follow this example then you can use online playground provided by [killercoda](https://killercoda.com/kubecon) 
This playground has two nodes ( 2 GB / 2 CPU ) - latest version kubernetes cluster ready to go. It also has helm installed nad browser-based VSCode to edit your yaml/code.the 

# Deploying using yaml/manifest files 

Clone my github repo :

`git clone https://github.com/ishswar/example-voting-app.git`

These has all the code we will use during this demo 

Change into to directory k8s-specifications `cd example-voting-app/k8s-specifications/`
These have YAML files to deploy 

1. Voting app - web app once vote received (via browser) - they are saved into Redis
1. Redis server
1. .NET code that scans Redis server and inserts votes into Database 
1. Database to store Votesthe  
1. Result app that shows votes via reading Database 

There are five apps above - which means we should have 5 Kubernetes deployment files - that is what you will find in `k8s-specifications` 
Now we also need a stable end-point to access apps above. 
The votting app and result app are exposed outside the cluster via NodePort and DB and Redis are exposed internally using ClusterIP.

```
|-- db-deployment.yaml
|-- db-service.yaml
|-- redis-deployment.yaml
|-- redis-service.yaml
|-- result-deployment.yaml
|-- result-service.yaml
|-- vote-deployment.yaml
|-- vote-service.yaml
`-- worker-deployment.yaml
```

## Deploy them 

We can deploy all of them in one shot using command (assuming you are in that directory ) 

`kubectl create -f .` 

output should look like 

```
controlplane $ kubectl create -f .
deployment.apps/db created
service/db created
deployment.apps/redis created
service/redis created
deployment.apps/result created
service/result created
deployment.apps/vote created
service/vote created
deployment.apps/worker created
```

Ideally, we should deploy DB and Redis first , then .NET app and last voting  app and result app - but above command does not guarantee that

After few seconds you should see all pods and service up and running..

Everything gets deployed in `default` namespace.

```
controlplane $ kubectl get pods && kubectl get svc
NAME                     READY   STATUS    RESTARTS   AGE
db-989b6b476-jqw6r       1/1     Running   0          2m28s
redis-7fdbb9576f-2vqvq   1/1     Running   0          2m28s
result-f9f4fbbc7-kzz6d   1/1     Running   0          2m28s
vote-5f865477fc-fb629    1/1     Running   0          2m28s
worker-667975666-8lbkr   1/1     Running   0          2m28s
NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
db           ClusterIP   10.97.51.10      <none>        5432/TCP         2m28s
kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP          26d
redis        ClusterIP   10.104.196.148   <none>        6379/TCP         2m28s
result       NodePort    10.97.138.2      <none>        5001:31001/TCP   2m28s
vote         NodePort    10.96.230.143    <none>        5000:31000/TCP   2m28s
```

You should be able to access voting GUI via URL like http://(node-ip):31000 - it will look like this : 

![](https://i.ibb.co/s5QMMtM/image.png)

Submit your vote and now you can access result page via URL like: http://(node-ip):31001 - it might look like this : 

![](https://i.ibb.co/r6RxLHf/image.png)

This concludes our steps of deploying multi-tier applications on kubernetes using YAML files.  

# Deploy using Helm 

Now let's create 

helm create db  
helm create vote
helm create redis
helm create worker
helm create result

rm -rf */templates/*.yaml
rm -rf */templates/*.txt
rm -rf */templates/tests

ls -la */templates/*

mv db-*.yaml db/templates/
mv vote-*.yaml vote/templates/
mv redis-*.yaml redis/templates/
mv worker-*.yaml worker/templates/
mv result*.yaml result/templates/
 
`git checkout with-helm-values`

`helm template vote ./vote -f ./vote/values.yaml`

`helm template vote ./vote -f ./vote/values-dev.yaml`

`helm template vote ./vote -f ./vote/values-dev.yaml --set service.nodeport=31006`

```
wget https://github.com/helmfile/helmfile/releases/download/v0.151.0/helmfile_0.151.0_linux_amd64.tar.gz
tar -xvf helmfile_0.151.0_linux_amd64.tar.gz 
mv helmfile /usr/sbin/
cd /root/example-voting-app/k8s-specifications
helmfile template  --set service.nodeport=31006 | grep -A10 -B15 31006
```

helmfile.yaml
```
environments:
  default:
   values:
    - default.gotmpl
  dev:
    values:
      - env.gotmpl
---

releases:
- name: vote
  chart: vote
  values:
    - service:
        type: NodePort
        nodeport: {{ .Environment.Values.vote.service.nodeport }}
- name: db
  chart: db
- name: result
  chart: result
- name: redis
  chart: redis
- name: worker
  chart: worker
```

env.gotmpl
```
---
vote:
  service:
    nodeport: "31007"
```

default.gotmpl
```
---
vote:
  service:
    nodeport: "31008"
```

```
environments:
  default:
   values:
    - default.gotmpl
  dev:
    values:
      - env.gotmpl
---

releases:
- name: vote
  chart: vote
  values:
   - vote/values-{{ .Environment.Name }}.yaml
- name: db
  chart: db
- name: result
  chart: result
- name: redis
  chart: redis
- name: worker
  chart: worker
```