# Jenkins local para el laboratorio

Imagen de Jenkins que corre el `Jenkinsfile` del repositorio sin configuración manual.

| Archivo | Qué hace |
|---|---|
| `Dockerfile` | Parte de `jenkins/jenkins:lts-jdk21` y agrega Docker CLI 28, Node.js 20 y Trivy 0.76.2, que son las herramientas que usan los stages |
| `plugins.txt` | Plugins de Pipeline, Git, Credentials Binding, Timestamper, vistas de stages, JCasC y Job DSL |
| `casc.yaml` | Configuración como código: usuario `admin`, sin registro abierto, sin acceso anónimo y el job `tasks-app-cd` apuntando a este repo |
| `entrypoint.sh` | No deja arrancar Jenkins si falta `JENKINS_ADMIN_PASSWORD` o tiene menos de 12 caracteres |

## Levantarlo

```bash
docker build -t lab-jenkins:local jenkins/

export JENKINS_ADMIN_PASSWORD="$(openssl rand -base64 18)"   # guárdala: es la del usuario admin
docker run -d --name jenkins-lab \
  --group-add 0 \
  -p 127.0.0.1:8081:8080 \
  -v jenkins_lab_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e JENKINS_ADMIN_PASSWORD \
  lab-jenkins:local
```

- **`-v /var/run/docker.sock`**: el Docker CLI del contenedor usa el daemon del host (Docker-outside-of-Docker). Las imágenes que construye el pipeline quedan en el Docker del host.
- **`--group-add 0`**: en Docker Desktop el socket pertenece a `root:root` con permisos `660`. Agregar el grupo 0 al usuario `jenkins` le da acceso sin correr Jenkins como root.
- **`127.0.0.1:8081`**: Jenkins solo es accesible desde el propio equipo.

> Montar el socket de Docker le da al contenedor control total del daemon del host. Sirve para un laboratorio local; en producción se usan agentes efímeros (Kubernetes, Docker Cloud) o builders sin daemon (Kaniko, BuildKit rootless).

## Credenciales del pipeline

En **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**:

| ID | Tipo | Contenido |
|---|---|---|
| `dockerhub-creds` | Username with password | Usuario de Docker Hub y un *personal access token* con permiso **Read & Write** |
| `sonar-token` | Secret text | Token de SonarQube (solo si se activa `ANALISIS_SONAR`) |

## Ejecutar el job

**tasks-app-cd → Build with Parameters**. En local, sin clúster ni servidor SonarQube:

| Parámetro | Valor | Motivo |
|---|---|---|
| `ANALISIS_SONAR` | `false` | El análisis ya corre en GitHub Actions contra SonarQube Cloud |
| `PUBLICAR` | `true` | Publica las imágenes en Docker Hub con la credencial `dockerhub-creds` |
| `DESPLEGAR` | `false` | El contenedor de Jenkins no tiene `kubectl` ni acceso al clúster de kind |

Los stages desactivados aparecen como *skipped* en la vista de stages; no fallan.
