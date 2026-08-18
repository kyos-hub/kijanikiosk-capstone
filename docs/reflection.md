# KijaniKiosk Capstone — Reflection

**Track A: Infrastructure-First**

## What did you get wrong, and what would you do differently?

The clearest mistake wasn't a technical one — it was a scope discipline
failure. After documenting in my scope document that the Week 10 serverless
receipt chain was explicitly out of scope for Track A, I still spent
significant time mid-project setting up an AWS account, configuring IAM,
and debugging a `serverless deploy` failure that turned out to be a missing
`CAPABILITY_NAMED_IAM` capability flag — a CloudFormation requirement for
stacks that create named IAM roles, surfaced only through a deliberately
vague "Validation failed with 1 error(s)" message until I checked
`aws cloudformation validate-template` directly.

That debugging skill itself was real and worth having. The mistake was not
setting a time-box before starting. I went in without deciding in advance
how long I'd give an explicitly descoped side-path before cutting my losses
and returning to Track A work that was still incomplete — the peer review,
the reflection, and spreading commits across more calendar days were all
still at zero while I chased a CloudFormation error. Next time, I'd set an
explicit limit ("I'll give this 30 minutes, then stop regardless of where
I am") before touching anything outside the committed scope document,
rather than letting the debugging problem itself decide how much time it
gets.

## What is the most important thing you learned, and what changed in your thinking?

The approval gate becoming a real, working checkpoint — not just a stage in
a diagram — was the moment the whole pattern clicked. Build #9 in the
recorded pipeline demo actually paused mid-run, waited for a human decision,
and required a typed `APPROVAL_REASON` before it would touch production.
Before building it, I understood "approval gate" as a term from the course
material. After watching it genuinely block progress until I typed a real,
specific reason referencing the actual smoke test result, I understood it
as a design choice: the gate isn't there to slow things down for its own
sake, it's there to force a documented human decision at the one point in
the pipeline where a mistake reaches real users. That's a different way of
thinking about automation — the goal isn't to remove humans from the loop,
it's to put them at the one place where their judgment actually matters and
record that they exercised it.

## What would you change on a second pass?

- **Replace the `hashicorp/http-echo` placeholder** with a real
  `kk-payments` container. The pipeline mechanics are proven independent of
  application code, but the live demo would be more convincing with actual
  payment logic behind the smoke test.
- **Add the error-rate and latency Prometheus rules** already drafted in
  `monitoring/kk-payments-alerts.yaml` but not wired to real metrics, once
  the application exposes genuine request instrumentation instead of relying
  solely on restart-count as a health signal.
- **Set an explicit time-box policy for out-of-scope exploration** before
  starting any future capstone-style project, so a legitimate debugging
  detour doesn't eat time budgeted for deliverables that are already
  committed to in the scope document.
