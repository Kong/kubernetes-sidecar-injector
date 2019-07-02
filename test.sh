#!/bin/bash

### Setup a ssl certificate
cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: kong-kong-admin.kong.svc
spec:
  request: $(openssl req -new -nodes -batch -keyout privkey.pem -subj /CN=kong-kong-admin.kong.svc | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF
kubectl certificate approve kong-kong-admin.kong.svc
kubectl -n kong create secret tls kong-kong-admin.kong.svc --key=privkey.pem --cert=<(kubectl get csr kong-kong-admin.kong.svc -o jsonpath='{.status.certificate}' | base64 --decode)
kubectl delete csr kong-kong-admin.kong.svc
rm privkey.pem

### Turn on sidecar injection
cat <<EOF | kubectl apply -f -
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
      namespace: default
      name: kong-kong-admin
      path: /kubernetes-sidecar-injector
    caBundle: $(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}')
EOF

kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.1/samples/bookinfo/platform/kube/bookinfo.yaml

