export SHELL:=/bin/bash
KONG_DIST_KUBERNETES_VERSION?=master
KONG_TEST_DATABASE?=postgres
KONG_SOURCE_LOCATION?="$$PWD/../kong/"

setup_tests:
	-rm -rf kong-dist-kubernetes
	git clone https://github.com/Kong/kong-dist-kubernetes.git
	cd kong-dist-kubernetes; \
	git fetch; \
	git reset --hard origin/$(KONG_DIST_KUBERNETES_VERSION)

test:
	-kubectl apply -f kube-registry.yaml
	docker build -t localhost:5000/kong-sidecar-injector .
	for i in {1..5}; do docker push localhost:5000/kong-sidecar-injector && break || sleep 15; done
	cd kong-dist-kubernetes; \
	sed -i -e 's/image: kong/image: localhost:5000\/kong-sidecar-injector/g' kong-*-postgres.yaml; \
	make run_postgres
	./test.sh
	