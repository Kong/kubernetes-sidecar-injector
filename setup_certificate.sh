#!/bin/bash

set -eufo pipefail

cd $(mktemp -d)

### Create a key+certificate for the control plane
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
kubectl create secret tls kong-kong-admin.kong.svc --key=privkey.pem --cert=<(kubectl get csr kong-kong-admin.kong.svc -o jsonpath='{.status.certificate}' | base64 --decode)
kubectl delete csr kong-kong-admin.kong.svc
rm privkey.pem