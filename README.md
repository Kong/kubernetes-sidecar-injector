# Howto

## Minikube

Start minikube with mutation admission webhook support.

```
minikube start
```

Old minikube/kubernetes < 1.9 will need this --extra-config:

```
minikube start --extra-config=apiserver.admission-control="NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota"
```

For inspecting the running system inside of minikube with docker, run:

```
eval $(minikube docker-env)
```


## Building custom docker image

The kubernetes sidecar injector plugin is not bundled in the Kong 1.0 docker image. Build and tag it with:

```
docker build -t kong .
```

You can then upload this to your docker repository with `docker push`, or if you can the above `minikube docker-env` command this will be loaded into your local kubernetes cluster.


## Setup Kong

```
kubectl create namespace kong
kubectl label namespace kong kong-sidecar-injection=disabled

### Create a key+certificate for the control plane
cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: kong-control-plane.kong.svc
spec:
  request: $(openssl req -new -nodes -batch -subj /CN=kong-control-plane.kong.svc | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF
kubectl certificate approve kong-control-plane.kong.svc
kubectl -n kong create secret tls kong-control-plane.kong.svc --key=privkey.pem --cert=<(kubectl get csr kong-control-plane.kong.svc -o jsonpath='{.status.certificate}' | base64 --decode)
kubectl delete csr kong-control-plane.kong.svc
rm privkey.pem

### Start database
kubectl -n kong apply -f resource_definitions/postgres.yaml

### Start control plane
kubectl apply -f resource_definitions/kong-control-plane.yaml

### Turn on kong plugins
KONG_ADMIN_URL=$(minikube service -n kong kong-control-plane --url | head -n 1)
curl $KONG_ADMIN_URL/plugins -d name=kubernetes-sidecar-injector

### Turn on sidecar injection
cat <<EOF | kubectl create -f -
apiVersion: admissionregistration.k8s.io/v1beta1
kind: MutatingWebhookConfiguration
metadata:
  name: kong-sidecar-injector
webhooks:
- name: kong.sidecar.injector
  rules:
  - apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
    operations: [ "CREATE" ]
  failurePolicy: Fail
  namespaceSelector:
    matchExpressions:
    - key: kong-sidecar-injection
      operator: NotIn
      values:
      - disabled
  clientConfig:
    service:
      namespace: kong
      name: kong-control-plane
      path: /kubernetes-sidecar-injector
    caBundle: $(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}')
EOF
```


## Debugging

### Logs from api server

These logs can be useful if the webhook doesn't seem to be getting called.

```
kubectl logs -n kube-system pod/kube-apiserver-minikube
```


### Logs from controller manager

Watch the logs of `kube-controller-manager-minikube` for JSONPatch issues

```
kubectl logs -n kube-system pod/kube-controller-manager-minikube
```


### Logs from kong

```
while true; do kubectl logs -n kong -f $(kubectl get pods -l app=kong-control-plane -n kong -o name); done
```


### Working on the plugin

```
docker build . -t kong && kubectl -n kong delete $(kubectl get pods -l app=kong-control-plane -n kong -o name)
```
