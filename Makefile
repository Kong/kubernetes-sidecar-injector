export SHELL:=/bin/bash
KONG_BUILD_TOOLS_VERSION?=master
KONG_TEST_DATABASE?=postgres
KONG_SOURCE_LOCATION?="$$PWD/../kong/"

setup_tests:
	-rm -rf kong-build-tools
	git clone https://github.com/Kong/kong-build-tools.git
	cd kong-build-tools; \
	git fetch; \
	git reset --hard origin/$(KONG_BUILD_TOOLS_VERSION)

test:
	docker build -t localhost:5000/kong-sidecar-injector .
	cd kong-build-tools; \
	KONG_TEST_CONTAINER_TAG=5000/kong-sidecar-injector \
	KONG_SOURCE_LOCATION=$(KONG_SOURCE_LOCATION) \
	KONG_VERSION=`docker run -it localhost:5000/kong-sidecar-injector kong version | tr -d '\040\011\012\015'` \
	RESTY_VERSION=1.13.6.2 \
	make test
	