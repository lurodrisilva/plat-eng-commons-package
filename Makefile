.PHONY: help plugin-install yamllint lint test snapshot-update package kubeconform clean all

# Default target
help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

## Install helm-unittest plugin
plugin-install: ## Install helm-unittest Helm plugin
	helm plugin install https://github.com/helm-unittest/helm-unittest --version "~1"

## Lint YAML files with yamllint
yamllint: ## Lint all non-template YAML files with yamllint
	@echo "Running yamllint..."
	yamllint .
	@echo ""
	@echo "YAML lint passed"

## Lint the library chart
lint: ## Lint the Helm library chart
	@echo "Linting plat-eng-commons-package..."
	helm lint .
	@echo ""
	@echo "Chart linted successfully"

## Run helm-unittest tests (graceful no-op when no tests are defined)
test: ## Run helm-unittest tests
	@if [ -n "$$(find tests/chart/tests/unit -name '*_test.yaml' 2>/dev/null | head -1)" ]; then \
		echo "Building test chart dependencies..."; \
		helm dependency build tests/chart > /dev/null 2>&1; \
		echo "Running helm-unittest tests..."; \
		helm unittest -f 'tests/unit/*.yaml' tests/chart; \
	else \
		echo "No tests found in tests/chart/tests/unit/ — skipping"; \
	fi

## Update helm-unittest snapshots
snapshot-update: ## Update helm-unittest snapshots
	@if [ -n "$$(find tests/chart/tests/unit -name '*_test.yaml' 2>/dev/null | head -1)" ]; then \
		echo "Building test chart dependencies..."; \
		helm dependency build tests/chart > /dev/null 2>&1; \
		echo "Updating helm-unittest snapshots..."; \
		helm unittest -u -f 'tests/unit/*.yaml' tests/chart; \
		echo "Snapshot update complete"; \
	else \
		echo "No tests found in tests/chart/tests/unit/ — nothing to snapshot"; \
	fi

## Package the library chart into a .tgz archive
package: ## Package the chart into a versioned .tgz archive
	@echo "Packaging plat-eng-commons-package..."
	helm package .
	@echo "Package complete"

## Validate rendered templates against Kubernetes schemas
kubeconform: ## Validate rendered test output with kubeconform
	@echo "Building test chart dependencies..."
	@helm dependency build tests/chart > /dev/null 2>&1
	@echo "Validating rendered output with kubeconform..."
	helm template test-release tests/chart | kubeconform -strict -summary
	@echo ""
	@echo "Kubeconform validation passed"

## Clean .tgz archive
clean: ## Remove packaged .tgz archives
	@echo "Cleaning plat-eng-commons-package..."
	rm plat-eng-commons-package-*.tgz
	@echo "Cleanup complete"

## Run lint and test
all: yamllint lint test kubeconform ## Run yamllint, lint, test, and kubeconform
	@echo ""
	@echo "All targets completed successfully"
