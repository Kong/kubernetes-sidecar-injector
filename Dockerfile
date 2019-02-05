FROM kong:1.0.3-alpine

COPY kong/ /usr/local/share/lua/5.1/kong/

ENV KONG_PLUGINS=bundled,kubernetes-sidecar-injector
