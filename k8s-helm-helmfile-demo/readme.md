

`git clone https://github.com/ishswar/example-voting-app.git`


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