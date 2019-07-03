#!/bin/bash

while [[ "$(kubectl get deployment -n kong kong-ingress-data-plane | tail -n +2 | awk '{print $4}')" != 1 ]]; do
  echo "waiting for Kong to be ready"
  sleep 10;
done

HOST="$(kubectl get nodes --namespace default -o jsonpath='{.items[0].status.addresses[0].address}')"
echo $HOST
ADMIN_PORT=$(kubectl get svc --namespace kong kong-control-plane -o jsonpath='{.spec.ports[0].nodePort}')
echo $ADMIN_PORT

curl http://$HOST:$ADMIN_PORT/plugins -d name=kubernetes-sidecar-injector -d config.image=localhost:5000/kong-sidecar-injector
sleep 10;

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

sleep 10;

kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.1/samples/bookinfo/platform/kube/bookinfo.yaml

sleep 10;

while [[ "$(kubectl get deployment details-v1 | tail -n +2 | awk '{print $4}')" != 1 ]]; do
  echo "waiting for bookinfo to be ready"

  sleep 10;
done

if [[ "$(kubectl get pods | grep details | awk '{print $2}')" != '2/2' ]]; then
  exit 1
fi

