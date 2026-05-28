# CMA Pipelines Agent Guide

## Release Version Bump Checklist

When shipping a new release, version metadata must be updated across multiple files. There are two scenarios:

### New semver (e.g. 2.19.0 → 2.20.0)

Update **all** of the following:

1. **`ARG CMA_VERSION`** in every Dockerfile (except the bundle, which uses a hardcoded `LABEL version`):
   - `Dockerfile.cma-operator`
   - `Dockerfile.keda-operator`
   - `Dockerfile.keda-adapter`
   - `Dockerfile.keda-webhooks`
   - `Dockerfile.http-addon-operator`
   - `Dockerfile.http-addon-scaler`
   - `Dockerfile.http-addon-interceptor`

2. **`LABEL version`** in `Dockerfile.cma-operator-bundle` (hardcoded, not from ARG)

3. **`cpe=` label** in all 8 Dockerfiles (major.minor only, e.g. `cpe:/a:redhat:openshift_custom_metrics_autoscaler:2.19::el9`)

4. **`LABEL com.redhat.openshift.versions`** in all 8 Dockerfiles if the target OCP version is changing

5. **`LABEL release`** in all 8 Dockerfiles — reset to `"1"` for a new semver

6. **`releaseNum`** file — reset to `1` (this gets appended to the CSV version in the bundle)

7. **FBC catalog templates** — update channel entries in:
   - `catalogs/fbc/catalog-template.yaml`
   - `catalogs/fbc-stage/catalog-template.yaml`

### Same semver, new release (e.g. security rebuild of 2.19.0)

Only increment the release number:

1. **`LABEL release`** in all 8 Dockerfiles — increment (e.g. `"1"` → `"2"`)
2. **`releaseNum`** file — increment to match
3. **FBC catalog templates** — update channel entries to reference the new `-N` suffix (e.g. `v2.19.0-1` → `v2.19.0-2`)
