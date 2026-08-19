# Contributing to Custom Metrics Autoscaler Pipelines

This repository contains the Konflux build pipelines, Dockerfiles, FBC catalogs, and release tooling for the Custom Metrics Autoscaler (CMA) for OpenShift. It does not contain Go source code — the source is pulled in via git submodules from the component repos.

## Related Resources

| Resource | Link |
|----------|------|
| KEDA operand repo | [openshift/kedacore-keda](https://github.com/openshift/kedacore-keda) |
| CMA operator repo | [openshift/custom-metrics-autoscaler-operator](https://github.com/openshift/custom-metrics-autoscaler-operator) |
| HTTP Add-on repo | [openshift/kedacore-http-add-on](https://github.com/openshift/kedacore-http-add-on) |
| AI guidance | [AGENTS.md](AGENTS.md) |
| OpenShift docs | [Custom Metrics Autoscaler](https://docs.openshift.com/container-platform/latest/nodes/cma/nodes-cma-autoscaling-custom.html) |

## Review and Approval Policy

Every change in every pull request must be understood and approved by two humans. This can be the PR author and a reviewer, or — if the author used an AI tool and does not fully understand the contents of the PR — two human reviewers.

**Exception:** PRs authored by deterministic automation tools that are part of our CI and related systems (whose code has been reviewed by the OpenShift engineering org) can be merged with a single human review.

Every change should be closely scrutinized. This repo defines how all CMA images are built and released — errors here can affect production builds. Review changes from multiple angles:

- **Build correctness**: Do Dockerfile changes produce the intended image? Are multi-stage builds intact?
- **Security**: Are there secrets, credentials, or elevated privileges introduced?
- **Release impact**: Could this change affect the operator bundle, FBC catalogs, or image pullspec references?
- **Cross-component effects**: Changes to shared Tekton pipelines or build-bump files affect multiple components.

## PR Title Convention

PR titles should be prefixed with a Jira ticket reference:

```
AUTOSCALE-123: Update keda-operator Dockerfile base image
OCPBUGS-456: Fix bundle pullspec rewriting
NO-JIRA: Update RPM lockfiles
```

## PR Workflow

This repo is in the `openshift` GitHub org and uses [Prow](https://docs.ci.openshift.org/) for PR management. Builds and tests are run by [Konflux](https://konflux-ci.dev/) via Tekton Pipelines-as-Code (the `.tekton/` directory).

### Required labels for merge

- `lgtm` — Added by a reviewer via the `/lgtm` command.
- `approved` — Added by an approver listed in the [OWNERS](OWNERS) file via the `/approve` command.

### Useful commands

Comment these on the PR:

| Command | Effect |
|---------|--------|
| `/lgtm` | Add the `lgtm` label after reviewing |
| `/lgtm cancel` | Remove the `lgtm` label |
| `/approve` | Add the `approved` label (OWNERS approvers only) |
| `/hold` | Prevent the PR from being merged |
| `/hold cancel` | Remove the hold and allow merging |
| `/retest` | Re-run failed required tests |
| `/cherry-pick <branch>` | Create a cherry-pick PR to a release branch |

### Preventing premature merges

- Add the `WIP:` prefix to the PR title. Prow adds the `do-not-merge/work-in-progress` label automatically.
- Use `/hold` to temporarily block merging while awaiting additional review or testing.

## Build System

This repo uses Konflux with Tekton Pipelines-as-Code. There are no Go tests or linters here — the repo's "tests" are Konflux pipeline runs that build container images.

### How builds are triggered

Each component has a pull-request and push PipelineRun definition in `.tekton/`. These use `on-cel-expression` filters so that only relevant components are built when their files change. Two shared pipeline definitions are used:

- `.tekton/multi-arch-build-pipeline.yaml` — Multi-arch image builds (most components)
- `.tekton/single-arch-build-pipeline.yaml` — Single-arch builds (FBC catalogs)

### Component nudging

When an operand or operator image is rebuilt, Konflux automatically opens PRs against this repo to update the image pullspec reference files in `bundle-hack/imagerefs/`. This keeps the operator bundle in sync with the latest built images.

## Verified Label

Use `/verified` to indicate changes have been verified. Examples:

```
/verified
/verified by Konflux build
/verified deferred to QE
```

## AI Code Review

Our repos use [CodeRabbit](https://coderabbit.ai/) for automated AI code review. As a courtesy to the human reviewer who follows, please address CodeRabbit's feedback before requesting human review. Responding with an explanation of why you are not acting on a suggestion is fine.

## Pre-Submit Checklist

Before requesting review:

1. Verify Dockerfiles build correctly (Konflux PR pipeline will test this)
2. If modifying FBC catalogs, run `bundle-hack/regen-fbc-catalog.sh` and commit the rendered output
3. If modifying bundle scripts, verify pullspec rewriting logic is correct
4. Review your diff for secrets, credentials, or debug code
5. Address any CodeRabbit review feedback
