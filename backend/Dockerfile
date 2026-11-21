FROM node:20-alpine

# Aplica los parches de seguridad del sistema operativo publicados después de la imagen base
# (openssl, musl, zlib).
RUN apk upgrade --no-cache

WORKDIR /app
COPY package*.json ./

# Instala solo dependencias de producción y luego elimina npm, npx, yarn y corepack.
# La app corre con "node" y no los usa en tiempo de ejecución; el npm incluido en la
# imagen base trae dependencias vulnerables (p. ej. tar, CVE-2026-59873, CRITICAL)
# que hacían fallar el quality gate de Trivy.
RUN npm ci --omit=dev --ignore-scripts \
 && npm cache clean --force \
 && rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
           /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
           /usr/local/bin/yarn /usr/local/bin/yarnpkg /opt/yarn-*

COPY src/ ./src/

ENV PORT=3000
EXPOSE 3000

# Buena práctica: no correr como root
USER node

CMD ["node", "src/server.js"]
