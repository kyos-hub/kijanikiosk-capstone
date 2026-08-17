# AI Governance Log

Note: The Week 10 capstone guide (Page 2) that defines the required eight-field
format was not available when this log was written. The structure below covers
the same required elements described in the rubric — what the AI produced, what
it got wrong, how the error was caught, what specific change was made, and a
reference to a governance checklist item — under equivalent field labels.

## Entry 1

- Date: 2026-08-17
- Tool: Claude (Sonnet)
- Task: Generate the initial Jenkins pipeline RBAC to allow the Jenkins build agent to deploy to kijani-staging and default namespaces.
- What it produced: A ClusterRole plus two RoleBindings binding to a ServiceAccount named jenkins in the jenkins namespace.
- What it got wrong: The binding target was incorrect. The Jenkins Helm chart's build agent pods run under a separate ServiceAccount named default in the jenkins namespace, not the jenkins controller's own ServiceAccount. This was not verified against the actual pod spec before the RBAC was generated.
- How the error was caught: The first real pipeline run failed at the Deploy to Staging stage with a Forbidden error naming system:serviceaccount:jenkins:default explicitly, which did not match the RBAC that had just been applied.
- What was changed: Both RoleBindings were edited to target the default ServiceAccount instead of jenkins, confirmed via kubectl get rolebinding -o yaml before re-running the pipeline.
- Governance checklist item referenced: Verify AI-suggested infrastructure configuration against the actual deployed system state, not assumptions about how a chart or tool is configured.

## Entry 2

- Date: 2026-08-17
- Tool: Claude (Sonnet)
- Task: Add a when { branch 'main' } condition to each Jenkinsfile stage so staging/production deploys only run on the main branch.
- What it produced: Four stages guarded with when { branch 'main' }, syntactically valid Jenkinsfile Groovy.
- What it got wrong: This guard only evaluates correctly inside a Multibranch Pipeline job, where Jenkins sets the BRANCH_NAME environment variable per branch. The job actually configured was a plain single-branch Pipeline job, which never sets BRANCH_NAME. Every guarded stage silently evaluated to false and was skipped on every run, while the overall pipeline still reported Finished: SUCCESS, which masked the problem.
- How the error was caught: The Console Output for the first pipeline run showed every stage after Tools Setup as "skipped due to when conditional," despite the top-level result being SUCCESS. This was noticed by reading the full console log rather than just the pass/fail status.
- What was changed: All four when { branch 'main' } blocks were removed, since the job only ever builds main by configuration, making the guard redundant for this setup.
- Governance checklist item referenced: A green/SUCCESS pipeline result does not by itself confirm the intended stages actually ran; console output must be checked, not just the final status.

## Entry 3

- Date: 2026-08-17
- Tool: Claude (Sonnet)
- Task: Grant the Jenkins ServiceAccount the Kubernetes permissions needed for the smoke test stage, which uses kubectl port-forward.
- What it produced: A ClusterRole granting get/list/watch/create/update/patch on pods, pods/log, services, and configmaps.
- What it got wrong: kubectl port-forward requires the separate pods/portforward subresource, which is not covered by permissions on pods alone. This was omitted from the first version of the ClusterRole.
- How the error was caught: The smoke test stage failed with curl returning status 000, and the console log showed the underlying cause: a Forbidden error specifically on pods/portforward, one stage after the earlier ServiceAccount fix had already resolved the Deploy to Staging failure.
- What was changed: Added a separate rule granting create on pods/portforward to the ClusterRole, applied it, and re-ran the pipeline to confirm the smoke test passed with a genuine HTTP 200.
- Governance checklist item referenced: Kubernetes RBAC subresources (such as pods/portforward, pods/exec, pods/log) must be granted explicitly and are easy to miss when only reasoning about the parent resource.
