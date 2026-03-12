# AGENTS.md — plat-eng-commons-package

Guidance for AI coding agents working in this repository.

## What This Repo Is

A **Helm library chart** (`type: library`) providing shared naming helpers and Kubernetes labels for the platform engineering stack. It cannot be installed directly — it is consumed as a dependency by application charts.

- **One template file**: `templates/_helpers.tpl` (37 lines, 5 named templates)
- **No application code**: no Go, Python, TypeScript, or other language files
- **Toolchain**: `helm` CLI + `make` (see `Makefile` for all common tasks)

---

## Commands

```bash
make help             # List all available targets
make yamllint         # Lint all non-template YAML files with yamllint
make lint             # Lint the chart — run after every change
make test             # Run helm-unittest tests (auto-builds deps)
make snapshot-update  # Update helm-unittest snapshots
make package          # Package the chart into a versioned .tgz archive
make kubeconform      # Validate rendered test output with kubeconform
make all              # yamllint + lint + test + kubeconform
make plugin-install   # Install the helm-unittest plugin (one-time setup)
```

**Run a single test suite** (faster during development):
```bash
helm dependency build tests/chart
helm unittest -f 'tests/unit/names_test.yaml' tests/chart   # names only
helm unittest -f 'tests/unit/labels_test.yaml' tests/chart  # labels only
```

**Lint** (primary validation — expected output: `1 chart(s) linted, 0 chart(s) failed`):
```bash
helm lint .   # [INFO] icon warning is expected and non-blocking
```

**Debug template rendering** (in a consuming chart context):
```bash
helm template <release-name> ./path/to/consuming-chart --debug
```

**CI** (GitHub Actions — runs automatically on push and PRs to `master`):
```
yamllint → lint → test → kubeconform
```
Workflow file: `.github/workflows/helm-ci.yml`
Trigger: push to any branch, pull_request targeting `master`
Steps: checkout → install Helm v3.20.0 → `make plugin-install` → install yamllint → install kubeconform → `make yamllint` → `make lint` → `make test` → `make kubeconform`

---

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── helm-ci.yml     # GitHub Actions CI: lint + test on push/PR
├── .yamllint.yml           # yamllint config (ignores Go template files)
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
│           └── unit/           # helm-unittest test suites (*_test.yaml)
├── README.md               # Consumer-facing documentation
├── .helmignore             # Patterns excluded from helm package
└── .gitignore              # Excludes *.tgz, charts/, *.prov, .sisyphus/
```

**Testing pattern**: Library charts produce no rendered resources and cannot be tested directly. A wrapper `type: application` chart at `tests/chart/` depends on the library via `file://../../` and calls each named template through a harness ConfigMap. Test suites assert on the rendered ConfigMap output.

---

## Template Authoring Rules

### Naming convention
All templates **must** use the `myorg.` prefix: `myorg.name`, `myorg.labels`, etc. Template names are globally scoped within a Helm release — never redefine `myorg.*` in consuming charts.

### Whitespace control
Always use `{{- ... -}}` (dash on both sides) for `define` blocks:
```yaml
{{- define "myorg.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
```

### Name truncation — mandatory on all name outputs
Every template producing a Kubernetes resource name **must** apply `| trunc 63 | trimSuffix "-"`. The 63-char limit is a Kubernetes constraint; `trimSuffix "-"` prevents trailing hyphens after truncation.

### Use `include` not `template`
`include` returns a string (pipeable); `template` returns nothing:
```yaml
# CORRECT
{{- include "myorg.labels" . | nindent 4 }}

# WRONG
{{ template "myorg.labels" . }}
```

### Indentation in output
Use `nindent N` when embedding multi-line template output:
```yaml
labels:
  {{- include "myorg.labels" . | nindent 4 }}        # metadata.labels
  matchLabels:
    {{- include "myorg.selectorLabels" . | nindent 6 }}  # matchLabels
```

### Conditional output
Guard optional fields with `{{- if }}`:
```yaml
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
```

### Merging maps from values
```yaml
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
```

---

## values.yaml Conventions

- Every property **must** have a comment starting with the property name:
  ```yaml
  # nameOverride is an optional override for the chart name used in resource naming.
  nameOverride: ""
  ```
- Values declared but not yet wired into templates must be annotated `(reserved — not currently used in templates; intended for future use)`
- Do **not** add `## @param`, `## @section`, or `## @skip` annotations — this repo does not use helm-docs
- `.Values.*` resolves from the **consuming chart's context** at render time, not from this library's `values.yaml`

---

## Chart.yaml Conventions

- `type: library` — must never be changed to `application`
- `version` follows SemVer; increment on every template or values change
- `appVersion` must stay in sync with `version`
- All four metadata fields must be present: `maintainers`, `keywords`, `home`, `sources`

---

## What NOT to Do

| Action | Why |
|--------|-----|
| Add non-`_helpers.tpl` template files | Library charts must not define installable resources |
| Change `type: library` to `application` | Breaks the library contract |
| Wire `commonAnnotations`, `team`, or `environment` into templates without a plan | Reserved; changes require a versioned release |
| Add `values.schema.json` | Not currently used; adds validation overhead without benefit |
| Commit `*.tgz`, `charts/`, or `*.prov` | Build artifacts — see `.gitignore` |
| Modify `_helpers.tpl` logic without bumping `version` in `Chart.yaml` | Consumers pin to chart versions |
| Test reserved values (`commonAnnotations`, `team`, `environment`) | No template wiring exists; testing creates false contracts |

---

## Adding a New Template

1. Add `{{- define "myorg.<name>" -}}` block to `templates/_helpers.tpl`
2. Apply `trunc 63 | trimSuffix "-"` if output is used as a Kubernetes name
3. Declare any new values in `values.yaml` with a `# propertyName is ...` comment
4. Add test cases to `tests/chart/tests/unit/` (or a new `*_test.yaml` file)
5. Document the template in `README.md` (Named Templates Reference table + Values table)
6. Bump `version` in `Chart.yaml` (patch for bug fix, minor for additive, major for breaking)
7. Run `make all` — must pass with 0 errors and 0 test failures

---

## Versioning Policy

| Change type | Version bump |
|-------------|-------------|
| New template or value (backward compatible) | Minor (`0.1.0` → `0.2.0`) |
| Bug fix in existing template | Patch (`0.1.0` → `0.1.1`) |
| Rename, remove, or change template output format | Major (`0.1.0` → `1.0.0`) |

Breaking changes require advance notice to all dependent charts before release.
