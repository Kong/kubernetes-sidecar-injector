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

## Setup Kong

### Run Kong on k8s

```
git clone https://github.com/Kong/kong-dist-kubernetes.git
cd kong-dist-kubernetes
make run_<postgres|cassandra>
```

or

```
kubectl apply -f https://raw.githubusercontent.com/Kong/kong-dist-kubernetes/master/kong-namespace.yaml
curl -fsSL https://raw.githubusercontent.com/Kong/kong-dist-kubernetes/master/setup_certificate.sh | bash
kubectl -n kong apply -f https://raw.githubusercontent.com/Kong/kong-dist-kubernetes/master/postgres.yaml
kubectl -n kong apply -f https://raw.githubusercontent.com/Kong/kong-dist-kubernetes/master/kong-control-plane-postgres.yaml
kubectl -n kong apply -f https://raw.githubusercontent.com/Kong/kong-dist-kubernetes/master/kong-ingress-data-plane-postgres.yaml
```

Wait for the Kong control and data planes to be running

```
kubectl -n kong get all
```

### Turn on kong plugins

```
export HOST=$(kubectl get nodes --namespace default -o jsonpath='{.items[0].status.addresses[0].address}')
export ADMIN_PORT=$(kubectl get svc --namespace kong kong-control-plane  -o jsonpath='{.spec.ports[0].nodePort}')
curl $HOST:$ADMIN_PORT/plugins -d name=kubernetes-sidecar-injector
```

### Turn on sidecar injection

```
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

or

```
curl -fsSL https://raw.githubusercontent.com/Kong/kong-dist-kubernetes/master/setup_sidecar_injector.sh | bash
```

Going forward any pod's that start get a Kong sidecar automatically injected 
which all data from the containers of that pod will flow through

For example starting the bookinfo.yaml example

```
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.1/samples/bookinfo/platform/kube/bookinfo.yaml
```

Every pod has an additional Kong docker dataplane image running

```
NAME                                  READY   STATUS    RESTARTS   AGE
pod/details-v1-5df567f4f6-vfj5z       2/2     Running   0          2m53
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
