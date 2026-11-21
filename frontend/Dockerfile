# 1.29 (mainline) en lugar de 1.27: la 1.27-alpine traía 3 CRITICAL y 65 HIGH en OpenSSL,
# brotli, curl, libxml2, etc. según Trivy.
FROM nginxinc/nginx-unprivileged:1.29-alpine

# Parches de seguridad del sistema operativo publicados después de la imagen base.
# Se necesita root solo para apk; luego se vuelve al usuario sin privilegios (UID 101).
USER root
RUN apk upgrade --no-cache
USER 101

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 8080
