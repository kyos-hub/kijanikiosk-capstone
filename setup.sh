#!/usr/bin/env bash
# Local setup script — run this from the repo root.
# Assumes: minikube is installed, Jenkins is already running locally,
# and kubectl/terraform/kustomize are on your PATH.
set -euo pipefail

echo "== 1. Confirming minikube is running =="
minikube status || (echo "Start minikube first: minikube start" && exit 1)

echo "== 2. Confirming kubectl context is minikube =="
CTX=$(kubectl config current-context)
if [ "$CTX" != "minikube" ]; then
  echo "kubectl context is '$CTX', expected 'minikube'. Run: kubectl config use-context minikube"
  exit 1
fi

echo "== 3. Provisioning kijani-staging namespace via Terraform =="
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
cd ..

echo "== 4. Deploying kk-payments to staging via kustomize =="
kubectl apply -k k8s/staging
kubectl rollout status deployment/kk-payments -n kijani-staging --timeout=120s

echo "== 5. Applying Prometheus alert rule (requires Prometheus Operator installed) =="
kubectl apply -f monitoring/kk-payments-alerts.yaml || \
  echo "WARNING: PrometheusRule apply failed — is the Prometheus Operator CRD installed? Skipping."

echo "== Done. Verify with: =="
echo "  kubectl get all -n kijani-staging"
echo "  kubectl get configmap kk-payments-config -n kijani-staging -o yaml"
