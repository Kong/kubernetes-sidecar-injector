export SHELL:=/bin/bash
KONG_DIST_KUBERNETES_VERSION?=origin/master
KONG_BUILD_TOOLS_VERSION?=6ef3856ed563112eac7985aa665e32270d9441f0

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
	sed -i -e 's/image: kong/image: localhost:5000\/kong-sidecar-injector/g' kong-*-postgres.yaml; \
	$(MAKE) run_postgres
	./test/test.sh
