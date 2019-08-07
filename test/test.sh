#!/bin/bash

set -e

export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"

counter=0
while [[ "$(kubectl get pod --all-namespaces | grep -v Running | grep -v Completed | wc -l)" != 1 ]]; do
  counter=$((counter + 1))
  if [ "$counter" -gt "30" ]
  then
    exit 1
  fi
  kubectl get pod --all-namespaces -o wide
  echo "waiting for K8s to be ready"
  sleep 10;
done

pushd kong-dist-kubernetes; \
make run_postgres; \
popd

counter=0
while [[ "$(kubectl get deployment kong-control-plane -n kong | tail -n +2 | awk '{print $4}')" != 1 ]]; do
  counter=$((counter + 1))
  if [ "$counter" -gt "30" ]
  then
    exit 1
  fi
  echo "waiting for Kong control plane to be ready"
  kubectl get pod --all-namespaces -o wide
  sleep 10;
done

counter=0
while [[ "$(kubectl get deployment kong-ingress-data-plane -n kong | tail -n +2 | awk '{print $4}')" != 1 ]]; do
  counter=$((counter + 1))
  if [ "$counter" -gt "30" ]
  then
    exit 1
  fi
  echo "waiting for Kong data plane to be ready"
  kubectl get pod --all-namespaces -o wide
  sleep 10;
done

HOST="$(kubectl get nodes --namespace default -o jsonpath='{.items[0].status.addresses[0].address}')"
echo $HOST
ADMIN_PORT=$(kubectl get svc --namespace kong kong-control-plane -o jsonpath='{.spec.ports[0].nodePort}')
echo $ADMIN_PORT

curl http://$HOST:$ADMIN_PORT/plugins -d name=kubernetes-sidecar-injector -d config.image=localhost:5000/kong-sidecar-injector

sleep 10;

./kong-dist-kubernetes/setup_sidecar_injector.sh

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
