export SHELL:=/bin/bash
KONG_DIST_KUBERNETES_VERSION?=master
KONG_BUILD_TOOLS_VERSION?=master

setup_tests:
	-rm -rf kong-build-tools
	git clone https://github.com/Kong/kong-build-tools.git
	cd kong-build-tools; \
	git reset --hard origin/"$(KONG_BUILD_TOOLS_VERSION)"; \
	$(MAKE) setup_tests
	-rm -rf kong-dist-kubernetes
	git clone https://github.com/Kong/kong-dist-kubernetes.git
	cd kong-dist-kubernetes; \
	git reset --hard origin/"$(KONG_DIST_KUBERNETES_VERSION)"
	kubectl apply -f kong-build-tools/kube-registry.yaml

test:
	docker build -t localhost:5000/kong-sidecar-injector .
	# Naive retry because the k8s docker registry sometimes fails
	for i in {1..5}; do docker push localhost:5000/kong-sidecar-injector && break || sleep 15; done
	cd kong-dist-kubernetes; \
	sed -i -e 's/image: kong/image: localhost:5000\/kong-sidecar-injector/g' kong-*-postgres.yaml; \
	$(MAKE) run_postgres
	./test.sh
