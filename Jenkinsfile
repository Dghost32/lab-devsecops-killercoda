// Pipeline CD — Jenkins
// Flujo: clonar → pruebas → SonarQube → build de imágenes → Trivy (gate) → publicar en Docker Hub
//        → desplegar en Kubernetes → smoke test (con rollback automático si algo falla).
//
// Requisitos en el agente: Docker CLI con acceso a un daemon, Node.js 20, Trivy y kubectl.
//   La imagen de jenkins/Dockerfile ya trae Docker CLI, Node.js y Trivy (ver jenkins/README.md).
// Credenciales en Jenkins (Manage Jenkins → Credentials):
//   - 'dockerhub-creds': usuario/token de Docker Hub (Username with password)
//   - 'sonar-token':     token de SonarQube (Secret text)
// Ningún secreto vive en este archivo: se inyectan con withCredentials y no quedan en el log.
pipeline {
  agent any

  // Interruptores para las etapas que dependen de infraestructura externa.
  // Por defecto el pipeline completo está activo; en un entorno local sin clúster o sin
  // servidor SonarQube se apagan al lanzar el build y Jenkins marca esas etapas como "skipped".
  parameters {
    booleanParam(name: 'ANALISIS_SONAR', defaultValue: true, description: 'Analizar con SonarQube (requiere servidor y credencial sonar-token)')
    booleanParam(name: 'PUBLICAR',       defaultValue: true, description: 'Publicar las imágenes en Docker Hub (requiere credencial dockerhub-creds)')
    booleanParam(name: 'DESPLEGAR',      defaultValue: true, description: 'Desplegar en Kubernetes y correr el smoke test (requiere kubectl con acceso al clúster)')
  }

  environment {
    REGISTRY      = 'docker.io/dghost32'
    // Versión inmutable por build: cada imagen publicada se puede rastrear hasta su ejecución.
    VERSION       = "1.0.${BUILD_NUMBER}"
    BACKEND_IMG   = "${REGISTRY}/tasks-backend:${VERSION}"
    FRONTEND_IMG  = "${REGISTRY}/tasks-frontend:${VERSION}"
    SONAR_HOST    = 'http://sonarqube:9000'
  }

  options {
    timestamps()                                  // hora en cada línea del log, útil para auditar
    timeout(time: 30, unit: 'MINUTES')            // evita builds colgados que bloqueen el agente
    buildDiscarder(logRotator(numToKeepStr: '20')) // conserva solo los últimos 20 builds
    disableConcurrentBuilds()                     // dos despliegues simultáneos se pisarían
  }

  stages {

    // 1. Trae el código exacto del commit que disparó el build (mismo repo y rama del job).
    //    Todo lo que sigue se construye a partir de esta copia, no de algo local del agente.
    stage('Clonar repositorio') {
      steps {
        checkout scm
        sh 'git log -1 --oneline'
      }
    }

    // 2. Las pruebas van antes del build: si la lógica falla, no tiene sentido gastar tiempo
    //    construyendo y escaneando imágenes. npm ci instala exactamente lo del package-lock.json.
    stage('Pruebas unitarias') {
      steps {
        dir('backend') {
          sh 'npm ci && npm test'
        }
      }
    }

    // 3. Análisis estático (SAST): bugs, code smells y secretos quemados en el código fuente.
    //    Se ejecuta con la imagen oficial del scanner para no instalarlo en el agente.
    stage('Análisis estático — SonarQube') {
      when { expression { params.ANALISIS_SONAR } }
      steps {
        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
          sh '''
            docker run --rm -v "$PWD:/usr/src" \
              -e SONAR_HOST_URL=$SONAR_HOST -e SONAR_TOKEN=$SONAR_TOKEN \
              sonarsource/sonar-scanner-cli:11
          '''
        }
      }
    }

    // 4. Empaqueta cada capa en una imagen Docker etiquetada con la versión del build.
    //    Backend y frontend son independientes, así que se construyen en paralelo.
    stage('Construir imágenes Docker') {
      parallel {
        stage('Backend')  { steps { sh "docker build -t ${BACKEND_IMG} backend/" } }
        stage('Frontend') { steps { sh "docker build -t ${FRONTEND_IMG} frontend/" } }
      }
    }

    // 5. Escaneo de la imagen ya construida (sistema operativo + dependencias empaquetadas).
    //    Los reportes HIGH/CRITICAL se archivan como evidencia; el gate detiene el pipeline
    //    si hay CRITICAL con parche disponible, ANTES de publicar nada en el registro.
    stage('Escaneo de imágenes — Trivy') {
      steps {
        sh "trivy image --severity HIGH,CRITICAL --format table --output trivy-backend.txt ${BACKEND_IMG}"
        sh "trivy image --severity HIGH,CRITICAL --format table --output trivy-frontend.txt ${FRONTEND_IMG}"
        // Quality gate: detiene el pipeline si hay vulnerabilidades CRITICAL con solución disponible
        sh "trivy image --severity CRITICAL --ignore-unfixed --exit-code 1 ${BACKEND_IMG}"
        sh "trivy image --severity CRITICAL --ignore-unfixed --exit-code 1 ${FRONTEND_IMG}"
      }
      post {
        always { archiveArtifacts artifacts: 'trivy-*.txt', allowEmptyArchive: true }
      }
    }

    // 6. Publica en Docker Hub solo imágenes que pasaron pruebas y escaneo.
    //    Las credenciales salen del almacén de Jenkins; --password-stdin evita que el token
    //    aparezca en la lista de procesos o en el log. Al final se cierra la sesión.
    stage('Publicar en el registro') {
      when { expression { params.PUBLICAR } }
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                          usernameVariable: 'REG_USER',
                                          passwordVariable: 'REG_PASS')]) {
          sh 'echo "$REG_PASS" | docker login -u "$REG_USER" --password-stdin'
          sh "docker push ${BACKEND_IMG}"
          sh "docker push ${FRONTEND_IMG}"
        }
      }
      post {
        always { sh 'docker logout || true' }
      }
    }

    // 7. Aplica los manifiestos y cambia la imagen de cada Deployment a la versión recién
    //    publicada. rollout status espera a que los pods nuevos estén listos (probes OK).
    stage('Desplegar en Kubernetes') {
      when { expression { params.DESPLEGAR } }
      steps {
        sh '''
          kubectl apply -f k8s/00-namespace.yaml
          kubectl apply -f k8s/10-backend.yaml -f k8s/20-frontend.yaml
          kubectl -n tareas set image deploy/backend  backend=$BACKEND_IMG
          kubectl -n tareas set image deploy/frontend frontend=$FRONTEND_IMG
          kubectl -n tareas rollout status deploy/backend  --timeout=120s
          kubectl -n tareas rollout status deploy/frontend --timeout=120s
        '''
      }
    }

    // 8. Verificación funcional mínima del despliegue: frontend → proxy → backend responde.
    //    Si falla, el bloque post hace rollback a la versión anterior.
    stage('Smoke test') {
      when { expression { params.DESPLEGAR } }
      steps {
        sh 'kubectl -n tareas run smoke --rm -i --restart=Never --image=curlimages/curl -- curl -sf http://frontend/api/health'
      }
    }
  }

  post {
    // Rollback solo si se intentó desplegar: devuelve backend y frontend a la revisión previa.
    failure {
      script {
        if (params.DESPLEGAR) {
          sh 'kubectl -n tareas rollout undo deploy/backend  || true'
          sh 'kubectl -n tareas rollout undo deploy/frontend || true'
        }
      }
    }
  }
}
