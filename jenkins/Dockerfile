# Jenkins para correr el Jenkinsfile del laboratorio en local.
# Agrega al controlador las herramientas que usan los stages: Docker CLI, Node.js 20 y Trivy.
# El Docker CLI habla con el daemon del host a través de /var/run/docker.sock (Docker-outside-of-Docker).
FROM node:20-bookworm-slim AS node
FROM docker:28-cli AS docker
FROM aquasec/trivy:0.76.2 AS trivy

FROM jenkins/jenkins:lts-jdk21

USER root
COPY --from=docker /usr/local/bin/docker /usr/local/bin/docker
COPY --from=trivy  /usr/local/bin/trivy  /usr/local/bin/trivy
COPY --from=node   /usr/local/bin/node   /usr/local/bin/node
COPY --from=node   /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Plugins y configuración como código (JCasC): sin asistente inicial, usuario admin y job creados al arrancar.
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
COPY casc.yaml /usr/share/jenkins/casc.yaml
ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/casc.yaml \
    JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

USER jenkins
