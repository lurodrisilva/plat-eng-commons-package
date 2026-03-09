# AGENTS.md — plat-eng-commons-package

Guidance for AI coding agents working in this repository.

## What This Repo Is

A **Helm library chart** (`type: library`) providing shared naming helpers and Kubernetes labels for the platform engineering stack. It cannot be installed directly — it is consumed as a dependency by application charts.

- **One template file**: `templates/_helpers.tpl` (37 lines, 5 named templates)
- **No application code**: no Go, Python, TypeScript, or other language files
- **Toolchain**: `helm` CLI + `make` (see `Makefile` for all common tasks)

---

## Commands

### Make targets (preferred — use these day-to-day)
```bash
make help             # List all available targets
make lint             # Lint the chart (primary validation — run after every change)
make test             # Run helm-unittest tests (graceful no-op when no tests exist)
make snapshot-update  # Update helm-unittest snapshots
make package          # Package the chart into a versioned .tgz archive
make all              # Run lint + test
make plugin-install   # Install the helm-unittest plugin (one-time setup)
```

### Lint (primary validation — run after every change)
```bash
helm lint .
# or: make lint
```
Expected output: `1 chart(s) linted, 0 chart(s) failed`
The `[INFO] Chart.yaml: icon is recommended` warning is expected and non-blocking.

### Package (produce distributable archive)
```bash
helm package .
# Output: plat-eng-commons-package-0.1.0.tgz (gitignored)
# or: make package
```

### Template rendering (debug helpers in context)
```bash
# Render a consuming chart's templates with this library as a dependency
helm template <release-name> ./path/to/consuming-chart --debug
```

### Helm unittest
```bash
# Build wrapper chart dependencies (required before first test run)
helm dependency build tests/chart

# Run all tests
helm unittest -f 'tests/unit/*.yaml' tests/chart
# or: make test  (handles dependency build automatically)

# Update snapshots
helm unittest -u -f 'tests/unit/*.yaml' tests/chart
# or: make snapshot-update
```

Tests live in `tests/chart/tests/unit/`. Library charts cannot be tested directly (no
renderable resources) — a wrapper `type: application` chart at `tests/chart/` depends on
the library and calls each named template through a harness ConfigMap.

### Dependency update (for consuming charts)
```bash
helm dependency update ./path/to/consuming-chart
```

---

## Repository Structure

```
.
├── Chart.yaml              # Chart metadata (name, version, type: library)
├── Makefile                # Common tasks: lint, test, package, snapshot-update
├── values.yaml             # Default values with inline documentation
├── templates/
│   └── _helpers.tpl        # All named templates (SOURCE OF TRUTH)
├── tests/
│   └── chart/              # Wrapper app chart for helm-unittest (type: application)
│       ├── Chart.yaml      # Depends on library via file://../../
│       ├── templates/
│       │   └── configmap.yaml  # Harness template calling all 5 library helpers
│       └── tests/
│           └── unit/           # helm-unittest test suites
│               ├── names_test.yaml    # myorg.name, myorg.fullname, myorg.chart
│               └── labels_test.yaml   # myorg.labels, myorg.selectorLabels
├── README.md               # Consumer-facing documentation
├── .helmignore             # Patterns excluded from helm package
└── .gitignore              # Excludes *.tgz, charts/, *.prov, .sisyphus/
```

---

## Template Authoring Rules

### Naming convention
- All templates **must** use the `myorg.` prefix: `myorg.name`, `myorg.labels`, etc.
- Template names are **globally scoped** within a Helm release — never redefine `myorg.*` in consuming charts.

### Whitespace control
Always use `{{- ... -}}` (dash on both sides) for `define` blocks to prevent blank-line output:
```yaml
{{- define "myorg.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
```

### Name truncation — mandatory on all name outputs
Every template that produces a Kubernetes resource name **must** apply:
```yaml
| trunc 63 | trimSuffix "-"
```
Kubernetes name fields have a 63-character limit. The `trimSuffix "-"` prevents trailing hyphens after truncation.

### Use `include` not `template`
Always use `include` (returns a string, pipeable) instead of `template` (returns nothing):
```yaml
# CORRECT
{{ include "myorg.labels" . }}
{{- include "myorg.labels" . | nindent 4 }}

# WRONG
{{ template "myorg.labels" . }}
```

### Indentation in output
Use `nindent N` (adds a leading newline + N spaces) when embedding multi-line template output:
```yaml
labels:
  {{- include "myorg.labels" . | nindent 4 }}   # metadata.labels → nindent 4
  matchLabels:
    {{- include "myorg.selectorLabels" . | nindent 6 }}  # matchLabels → nindent 6
```

### Conditional output
Use `{{- if .Value }}` guards for optional fields (see `app.kubernetes.io/version` in `myorg.labels`):
```yaml
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
```

### Merging maps from values
Use `{{- with .Values.someMap }}{{ toYaml . }}{{- end }}` to safely merge optional map values:
```yaml
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
```

---

## values.yaml Conventions

### Comment format (Helm best practice — mandatory)
Every property **must** have a comment that starts with the property name:
```yaml
# nameOverride is an optional override for the chart name used in resource naming.
nameOverride: ""
```

### Reserved values
Values declared but not yet wired into templates must be annotated:
```yaml
# team is the team identifier for resource ownership tracking.
# (reserved — not currently used in templates; intended for future use)
team: ""
```

### No helm-docs annotations
Do **not** add `## @param`, `## @section`, or `## @skip` annotations — this repo does not use helm-docs tooling.

### Parent chart context
Values in this library's `values.yaml` are **defaults only**. At render time, `.Values.*` resolves from the consuming application chart's context, not this file.

---

## Chart.yaml Conventions

- `type: library` — must never be changed to `application`
- `version` follows [SemVer](https://semver.org/): increment on every template or values change
- `appVersion` must stay in sync with `version` (library charts track no external application)
- All four metadata fields must be present: `maintainers`, `keywords`, `home`, `sources`

---

## What NOT to Do

| Action | Why |
|--------|-----|
| Add non-`_helpers.tpl` template files | Library charts must not define installable resources |
| Change `type: library` to `application` | Breaks the library contract |
| Wire `commonAnnotations`, `team`, or `environment` into templates without a plan | These are reserved; changes require a versioned release |
| Add `values.schema.json` | Not currently used; adds validation overhead without benefit |
| Commit `*.tgz`, `charts/`, or `*.prov` | These are build artifacts — see `.gitignore` |
| Modify `_helpers.tpl` logic without bumping `version` in `Chart.yaml` | Consumers pin to chart versions |

---

## Adding a New Template

1. Add the `{{- define "myorg.<name>" -}}` block to `templates/_helpers.tpl`
2. Apply `trunc 63 | trimSuffix "-"` if the output is used as a Kubernetes name
3. Declare any new values in `values.yaml` with a `# propertyName is ...` comment
4. Document the template in `README.md` (Named Templates Reference table + Values table)
5. Bump `version` in `Chart.yaml` (patch for additive, minor for new behavior, major for breaking)
6. Run `helm lint .` — must pass with 0 errors

---

## Versioning Policy

| Change type | Version bump |
|-------------|-------------|
| New template or value (backward compatible) | Minor (`0.1.0` → `0.2.0`) |
| Bug fix in existing template | Patch (`0.1.0` → `0.1.1`) |
| Rename, remove, or change template output format | Major (`0.1.0` → `1.0.0`) |

Breaking changes require advance notice to all dependent charts before release.
