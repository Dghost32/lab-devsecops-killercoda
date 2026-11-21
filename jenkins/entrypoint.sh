#!/bin/bash
set -euo pipefail
if [ -z "${JENKINS_ADMIN_PASSWORD:-}" ] || [ "${#JENKINS_ADMIN_PASSWORD}" -lt 12 ]; then
  echo "ERROR: define JENKINS_ADMIN_PASSWORD (mínimo 12 caracteres) al lanzar el contenedor." >&2
  exit 1
fi
exec /usr/bin/tini -- /usr/local/bin/jenkins.sh "$@"
