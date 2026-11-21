#!/bin/bash
# Falla cerrado: sin contraseña de admin, Jenkins no arranca (evita un admin con contraseña vacía).
set -euo pipefail
if [ -z "${JENKINS_ADMIN_PASSWORD:-}" ] || [ "${#JENKINS_ADMIN_PASSWORD}" -lt 12 ]; then
  echo "ERROR: define JENKINS_ADMIN_PASSWORD (mínimo 12 caracteres) al lanzar el contenedor." >&2
  exit 1
fi
exec /usr/bin/tini -- /usr/local/bin/jenkins.sh "$@"
