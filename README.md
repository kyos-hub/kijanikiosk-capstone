# KijaniKiosk Capstone — Track A (Infrastructure-First)

## Status

Core infrastructure is built and proven working end-to-end: Terraform-provisioned staging namespace, kk-payments deployed to both staging and production from a shared manifest with environment-specific config, a Prometheus alert rule, and a Jenkins pipeline that deploys to staging, runs a smoke test, pauses for a human approval with a captured reason, then deploys to production. The serverless receipt chain is explicitly out of scope for this submission — see below.

## What's here

- terraform/ — Provisions the kijani-staging namespace + resource quota
- k8s/base/ — Shared Deployment + Service manifest (same file, both envs)
- k8s/staging/ — Kustomize overlay: staging ConfigMap (DB_HOST, bucket, etc.)
- k8s/production/ — Kustomize overlay: production ConfigMap
- jenkins/Jenkinsfile — Staging deploy -> smoke test -> approval gate -> prod deploy
- jenkins/rbac.yaml — RBAC granting the Jenkins build agent's ServiceAccount access to deployments/services/configmaps/pods/portforward in kijani-staging and default namespaces only
- monitoring/alerts/ — Prometheus PrometheusRule: alerts on kk-payments restart count (more than 3 restarts in 15m)
- setup.sh — Runs the whole thing in order

## Known gaps (deliberate scope decisions)

1. kk-payments is a placeholder image (hashicorp/http-echo), not the real application. No production-ready kk-payments container exists in this environment. http-echo responds 200 on any path, including /healthz, so the Deployment, probes, ConfigMap wiring, and smoke test could all be validated against real Kubernetes behaviour. Swapping in a real image is a drop-in change to k8s/base/deployment.yaml — nothing else in the pipeline, RBAC, or manifests would need to change.

2. The Week 10 serverless receipt chain is not integrated. The original Week 10 project files were not available when this capstone was built, and this environment has no cloud provider credentials configured (confirmed: no AWS CLI, no cloud env vars). Rebuilding four Lambda-equivalent functions and a real S3 event chain from scratch, with no real cloud target to deploy to, was judged out of scope given the time available. The staging and production ConfigMaps already define RECEIPTS_BUCKET (pointing at kk-payments-receipts-staging / -production respectively) so the integration seam is prepared, but nothing currently writes to or reads from those buckets.

## Running it locally

1. Start minikube and set the context: minikube start, then kubectl config use-context minikube
2. Provision the namespace: terraform -chdir=terraform init, then terraform -chdir=terraform apply
3. Deploy the app to both environments: kubectl apply -k k8s/staging, then kubectl apply -k k8s/production
4. Install monitoring: helm repo add prometheus-community https://prometheus-community.github.io/helm-charts, then helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace --set grafana.enabled=false --set nodeExporter.enabled=false, then kubectl apply -f monitoring/alerts/kk-payments-alerts.yaml
5. Install Jenkins: helm repo add jenkins https://charts.jenkins.io, then helm install jenkins jenkins/jenkins --namespace jenkins --create-namespace, then kubectl apply -f jenkins/rbac.yaml
6. Port-forward into Jenkins and get the admin password: kubectl --namespace jenkins port-forward svc/jenkins 8080:8080, then in another terminal, kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password
7. In the Jenkins UI, create a Pipeline job (not Multibranch) pointed at this repo's main branch, with Script Path jenkins/Jenkinsfile and a Poll SCM trigger set to H/2 * * * *. No Git credentials are needed since this repo is public. No kubeconfig credential is needed either — Jenkins authenticates via its own build agent's in-cluster ServiceAccount, which jenkins/rbac.yaml grants access to the relevant namespaces.

## Verifying the ConfigMap separation

Run: kubectl get configmap kk-payments-config -n kijani-staging -o jsonpath='{.data.DB_HOST}'
Then: kubectl get configmap kk-payments-config -n default -o jsonpath='{.data.DB_HOST}'

These return different values (kk-payments-db.kijani-staging.svc.cluster.local vs kk-payments-db.default.svc.cluster.local) while both Deployments reference the exact same k8s/base/deployment.yaml.

## Demonstrating the pipeline

Trigger a build via Build Now in the Jenkins UI, or push a commit to main (the Poll SCM trigger checks every ~2 minutes). The pipeline will deploy to staging, run a smoke test against /healthz, then pause and wait for a human to type an APPROVAL_REASON and approve before deploying to production.

To demonstrate a failing smoke test / fault-handling path: temporarily break the readiness probe path in k8s/base/deployment.yaml (point it at a path http-echo won't answer with 200), push to main, and show the pipeline fail before reaching the approval gate.

## Troubleshooting notes from building this

- The Jenkins Helm chart's build agents run as system:serviceaccount:jenkins:default, not the Jenkins controller's own jenkins ServiceAccount. RBAC must target default in the jenkins namespace — confirmed via a Forbidden error during the first real pipeline run.
- kubectl port-forward requires the pods/portforward subresource explicitly. It is not covered by pods alone.
- when { branch 'main' } guards only evaluate correctly in a Multibranch Pipeline job, where BRANCH_NAME is set. A plain single-branch Pipeline job never sets it, so those guards silently skip every stage even though the build reports SUCCESS.
