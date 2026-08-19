# Custom Metrics Autoscaler Pipelines

This repository contains the [Konflux](https://konflux-ci.dev/) build pipeline definitions, Dockerfiles, and release tooling for the **Custom Metrics Autoscaler (CMA)** for OpenShift. It does not contain the product's source code — instead, it pulls source from upstream repos via git submodules and defines everything needed to build, bundle, and release the CMA container images.

## What Gets Built

This repo produces the following container images via Konflux multi-arch builds (amd64, arm64, s390x, ppc64le):

| Image | Dockerfile | Source Submodule |
|-------|-----------|------------------|
| keda-operator | `Dockerfile.keda-operator` | `kedacore-keda` |
| keda-adapter | `Dockerfile.keda-adapter` | `kedacore-keda` |
| keda-webhooks | `Dockerfile.keda-webhooks` | `kedacore-keda` |
| cma-operator | `Dockerfile.cma-operator` | `custom-metrics-autoscaler-operator` |
| cma-operator-bundle | `Dockerfile.cma-operator-bundle` | `custom-metrics-autoscaler-operator` |
| http-addon-operator | `Dockerfile.http-addon-operator` | `kedacore-http-add-on` |
| http-addon-scaler | `Dockerfile.http-addon-scaler` | `kedacore-http-add-on` |
| http-addon-interceptor | `Dockerfile.http-addon-interceptor` | `kedacore-http-add-on` |

Additionally, File-Based Catalog (FBC) images are built for each supported OCP version from `catalogs/fbc/` (production) and `catalogs/fbc-stage/` (staging).

## Related Repositories

| Repo | Relationship |
|------|-------------|
| [openshift/kedacore-keda](https://github.com/openshift/kedacore-keda) | KEDA operand source (downstream fork) |
| [openshift/custom-metrics-autoscaler-operator](https://github.com/openshift/custom-metrics-autoscaler-operator) | CMA operator source |
| [openshift/kedacore-http-add-on](https://github.com/openshift/kedacore-http-add-on) | HTTP Add-on source (downstream fork) |

## User Documentation

[Custom Metrics Autoscaler — OpenShift Docs](https://docs.openshift.com/container-platform/latest/nodes/cma/nodes-cma-autoscaling-custom.html)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development workflow and conventions. See [AGENTS.md](AGENTS.md) for AI-specific guidance.

## More Information

- [Konflux onboarding process](docs/konflux-onboarding.md)
- [Functionality demonstrated](docs/functionality-demonstrated.md)
