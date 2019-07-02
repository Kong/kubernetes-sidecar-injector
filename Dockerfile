FROM kong

COPY kong/plugins/kubernetes-sidecar-injector /usr/local/share/lua/5.1/kong/plugins/kubernetes-sidecar-injector

RUN chmod 664 /usr/local/share/lua/5.1/kong/plugins/kubernetes-sidecar-injector/*
