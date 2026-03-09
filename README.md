# plat-eng-commons-package

[![CI](https://github.com/lurodrisilva/plat-eng-commons-package/actions/workflows/ci.yml/badge.svg)](https://github.com/lurodrisilva/plat-eng-commons-package/actions/workflows/helm-ci.yml)

A Helm library chart providing common naming helpers and Kubernetes labels for the platform engineering stack.

> **This chart is a library chart. It cannot be installed directly.** Add it as a dependency in your application chart.

## TL;DR

```yaml
# In your application chart's Chart.yaml:
dependencies:
  - name: plat-eng-commons-package
    version: "~0.1.0"
    repository: "oci://your-registry.example.com/helm-charts"
```

```bash
helm dependency update ./your-chart
```

```yaml
# In your application chart's templates:
metadata:
  name: {{ include "myorg.fullname" . }}
  labels:
    {{- include "myorg.labels" . | nindent 4 }}
```

## Prerequisites

- Helm 3.x
- Kubernetes 1.21+

## Installation

1. Add this chart as a dependency in your application chart's `Chart.yaml`:

```yaml
dependencies:
  - name: plat-eng-commons-package
    version: "~0.1.0"
    repository: "oci://your-registry.example.com/helm-charts"
```

2. Update dependencies:

```bash
helm dependency update ./your-chart
```

3. Use the helpers in your templates — see [Named Templates Reference](#named-templates-reference) below.

## Named Templates Reference

All templates are namespaced with the `myorg.` prefix. They are globally scoped within a release — do not redefine them in your own chart.

| Template | Description | Input | Usage Example |
|----------|-------------|-------|---------------|
| `myorg.name` | Returns the chart name. Respects `.Values.nameOverride`. Truncated to 63 chars. | Chart context (`.`) | `{{ "{{" }} include "myorg.name" . {{ "}}" }}` |
| `myorg.fullname` | Returns the fully qualified resource name (`{release}-{chart}`). If release name already contains chart name, uses release name only. Respects `.Values.fullnameOverride`. Truncated to 63 chars. | Chart context (`.`) | `{{ "{{" }} include "myorg.fullname" . {{ "}}" }}` |
| `myorg.chart` | Returns the chart identifier label value (`{chartName}-{chartVersion}`). Replaces `+` with `_`. Truncated to 63 chars. | Chart context (`.`) | `{{ "{{" }} include "myorg.chart" . {{ "}}" }}` |
| `myorg.selectorLabels` | Returns `app.kubernetes.io/name` and `app.kubernetes.io/instance` selector labels. Use in `matchLabels` and pod template selectors. | Chart context (`.`) | `{{- include "myorg.selectorLabels" . \| nindent 6 }}` |
| `myorg.labels` | Returns the full recommended label set: `helm.sh/chart`, selector labels, `app.kubernetes.io/version` (when `.Chart.AppVersion` is set), `app.kubernetes.io/managed-by`, plus any entries from `.Values.commonLabels`. | Chart context (`.`) | `{{- include "myorg.labels" . \| nindent 4 }}` |

### Usage example

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myorg.fullname" . }}
  labels:
    {{- include "myorg.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "myorg.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "myorg.labels" . | nindent 8 }}
```

## Values

Values are resolved from the **consuming application chart's context** — not from this library chart's own `values.yaml`. See [Important Notes](#important-notes) for details.

| Parameter | Description | Default | Status |
|-----------|-------------|---------|--------|
| `nameOverride` | Override the chart name used in resource naming. Used by `myorg.name` and `myorg.fullname`. | `""` | Active |
| `fullnameOverride` | Override the fully qualified resource name. Replaces the default `{release}-{chart}` pattern. Used by `myorg.fullname`. | `""` | Active |
| `commonLabels` | Map of additional labels merged into the output of `myorg.labels`. | `{}` | Active |
| `commonAnnotations` | Map of additional annotations for resources. | `{}` | Reserved |
| `team` | Team identifier for resource ownership tracking. | `""` | Reserved |
| `environment` | Deployment environment name (e.g., `dev`, `staging`, `production`). | `""` | Reserved |

> **Reserved** values are declared but not currently used in any template. They are reserved for future implementation.

## Important Notes

### Values come from the parent chart

When this library chart is used as a dependency, all `.Values.*` references in its templates resolve from the **consuming application chart's `values.yaml`** — not from this chart's own `values.yaml`. The library's `values.yaml` provides default values only.

To set `commonLabels`, add this to your **application chart's** `values.yaml`:

```yaml
commonLabels:
  team: platform
  environment: production
```

### Template namespace collision

All templates in this library use the `myorg.` prefix. **Do not define templates with this prefix in your own chart** — Helm templates are globally scoped within a release, and duplicate names will cause unpredictable behavior.

### Governance

- This library is owned and maintained by the Platform Engineering team.
- Application teams should consume these helpers as-is. **Do not fork or patch locally.**
- Breaking changes will be released under a new major version with advance notice to all dependent charts.
