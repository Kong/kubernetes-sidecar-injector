export SHELL:=/bin/bash
KONG_DIST_KUBERNETES_VERSION?=origin/master
KONG_BUILD_TOOLS_VERSION?=76500d371afa4b4abb4cff5dc63ae1e2e6ff9e4a
K8S_VERSION?=v1.15.0

setup_tests:
	curl -fsSL https://raw.githubusercontent.com/Kong/kong-build-tools/${KONG_BUILD_TOOLS_VERSION}/.ci/setup_kind.sh | bash
	-rm -rf kong-dist-kubernetes
	git clone https://github.com/Kong/kong-dist-kubernetes.git
	cd kong-dist-kubernetes; \
	git reset --hard "$(KONG_DIST_KUBERNETES_VERSION)"

.PHONY: test
test:
	docker build -t localhost:5000/kong-sidecar-injector .
	kind load docker-image localhost:5000/kong-sidecar-injector
	cd kong-dist-kubernetes; \
	sed -i -e 's/image: kong/image: localhost:5000\/kong-sidecar-injector/g' kong-*-postgres.yaml
	./test/test.sh
