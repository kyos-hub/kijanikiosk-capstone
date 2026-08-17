# Testing & Feedback Log (Self-Review)

Note: No classmate was available for a peer review session. This is a documented
self-review instead, conducted by re-examining the pipeline, RBAC, and README
after the initial build was working end-to-end.

## Test plan (written before the review)

- Confirm the pipeline actually runs every stage on a fresh trigger, not just
  reports SUCCESS.
- Confirm RBAC grants exactly what each pipeline stage needs, no more, no less.
- Confirm the README's setup steps are accurate against the current system state,
  not the original scaffolding.

## Issue 1

- Issue: The Jenkinsfile's `when { branch 'main' }` guards caused every deploy
  stage to be silently skipped, even though the pipeline reported `Finished:
  SUCCESS`.
- Severity: High — the pipeline appeared to work but did nothing.
- Resolution: Removed the guards, since the job only ever builds `main` by its
  own configuration (Branch Specifier `*/main`), making them redundant.
- Evidence: commit 9216110, "fix(jenkins): remove branch 'main' when-guards
  blocking all deploy stages".

## Issue 2

- Issue: RBAC was bound to the `jenkins` ServiceAccount, but Jenkins build
  agent pods actually run as the `default` ServiceAccount in the `jenkins`
  namespace. Every `kubectl apply` from the pipeline failed with Forbidden.
- Severity: High — blocked all deployment stages.
- Resolution: Rebound both RoleBindings to the `default` ServiceAccount.
- Evidence: commit e7eb6ab, "fix(jenkins): bind RBAC to the build agent's
  actual ServiceAccount".

## Issue 3

- Issue: The smoke test stage failed even after the ServiceAccount fix, because
  `kubectl port-forward` requires the `pods/portforward` subresource, which
  wasn't included in the original ClusterRole.
- Severity: Medium — blocked the smoke test and everything downstream of it,
  but staging deploy itself worked.
- Resolution: Added an explicit rule granting `create` on `pods/portforward`.
- Evidence: commit b0a1660, "fix(jenkins): add pods/portforward permission for
  smoke test".

## Improvement committed as a result of this review

The README was completely out of date — it was still the pre-work scaffolding
TODO list, describing a `minikube-kubeconfig` Jenkins credential that no longer
exists after switching to in-cluster ServiceAccount auth, and listing the
serverless chain as something to "wire in" with no mention that it had been
scoped out. This was rewritten to reflect the actual working system, its real
setup steps, and the two deliberate scope exclusions with reasons.

- Evidence: commit 1047270, "docs(readme): rewrite to reflect actual system
  state and known gaps". Before/after comparison: `git show
  b0a1660:README.md` (old) vs current `README.md` on `main`.
