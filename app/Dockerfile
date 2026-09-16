# Unprivileged base image: listens on 8080 and runs as a non-root user by
# default, which is what makes the pod's readOnlyRootFilesystem +
# runAsNonRoot security context (see k8s/base/deployment.yaml) work without
# extra plumbing.
FROM nginxinc/nginx-unprivileged:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY site/ /usr/share/nginx/html/

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s CMD wget -q -O- http://127.0.0.1:8080/ || exit 1
