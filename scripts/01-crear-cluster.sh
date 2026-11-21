#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if kind get clusters 2>/dev/null | grep -qx lab; then
  echo "==> El cluster 'lab' ya existe"
else
  echo "==> Creando cluster 'lab' (1–2 minutos)"
  kind create cluster --config scripts/kind-config.yaml --wait 120s
fi

kubectl cluster-info --context kind-lab
kubectl get nodes -o wide
