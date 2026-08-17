# KijaniKiosk Capstone — Track A (Infrastructure-First)

## Status: starter scaffolding, not a finished submission

This is a working starting point for the infrastructure layer, not a complete
capstone. You still need to:

- Point `k8s/base/deployment.yaml` at your actual `kk-payments` image
- Confirm the app actually exposes `/healthz` (or change the probes/smoke test to match)
- Set up the `minikube-kubeconfig` credential in Jenkins referenced in `jenkins/Jenkinsfile`
- Install the Prometheus Operator in minikube if it isn't already there, or adapt
  `monitoring/kk-payments-alerts.yaml` to plain Prometheus config
- Wire in the Week 10 serverless receipt chain (not included here — that's your
  existing Week 10 work, connected via the `RECEIPTS_BUCKET` env var already set
  in the staging/production ConfigMaps)
- Write the actual README sections, scope PDF, governance log, peer feedback log,
  slide deck, and reflection — none of that is here, and none of it can be
  generated on your behalf per the assignment's own integrity rules

## What's here

```
terraform/          Provisions the kijani-staging namespace + resource quota
k8s/base/            Shared Deployment + Service manifest (same file, both envs)
k8s/staging/         Kustomize overlay: staging namespace + staging ConfigMap
k8s/production/      Kustomize overlay: production namespace + production ConfigMap
jenkins/Jenkinsfile  Staging deploy -> smoke test -> approval gate -> prod deploy
monitoring/          Prometheus alert rules for kk-payments
setup.sh             Runs the whole thing in order
```

## Running it locally

```bash
minikube start
kubectl config use-context minikube
chmod +x setup.sh
./setup.sh
```

Then point your local Jenkins at this repo (or copy `jenkins/Jenkinsfile` in as
your pipeline definition) and configure a `minikube-kubeconfig` credential
pointing at `~/.kube/config`.

## Testing the smoke test / approval gate live

To demonstrate a **failing** smoke test (required for the "fault handling" demo
point in the rubric): temporarily break the `/healthz` path in your app, push to
main, and show the pipeline stop before the approval gate.

To demonstrate the gate working: fix it, push again, and show the pipeline pause
for approval, then approve with a reason and watch it deploy to production.

## Verifying the ConfigMap separation

```bash
kubectl get configmap kk-payments-config -n kijani-staging -o jsonpath='{.data.DB_HOST}'
kubectl get configmap kk-payments-config -n default -o jsonpath='{.data.DB_HOST}'
```

These should return different values while both Deployments reference the exact
same `deployment.yaml`.
