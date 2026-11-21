FROM node:24-alpine

RUN apk upgrade --no-cache

WORKDIR /app
COPY package*.json ./

RUN npm ci --omit=dev --ignore-scripts \
 && npm cache clean --force \
 && rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
           /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
           /usr/local/bin/yarn /usr/local/bin/yarnpkg /opt/yarn-*

COPY src/ ./src/

ENV PORT=3000
EXPOSE 3000

USER 1000

CMD ["node", "src/server.js"]
