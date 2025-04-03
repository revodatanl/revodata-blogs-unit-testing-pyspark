.PHONY: install setup clean test deploy_% destroy_% repo module module_% tree docs

install:
	@CURRENT_OS=$$(uname -s); \
	echo "Current OS: $$CURRENT_OS"; \
	if [ "$$CURRENT_OS" = "Darwin" ]; then \
		echo "Verifying if Homebrew is installed..."; \
		which brew > /dev/null || (echo "Homebrew is not installed. Installing Homebrew..." && /bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"); \
		echo "Installing tools..."; \
		for tool in git uv; do \
			if ! command -v $$tool >/dev/null 2>&1; then \
				echo "Installing $$tool..."; \
				brew install $$tool; \
			else \
				echo "$$tool is already installed. Skipping."; \
			fi; \
		done; \
	elif [ "$$CURRENT_OS" = "Linux" ]; then \
		echo "Installing tools..."; \
		if ! command -v git >/dev/null 2>&1; then \
				echo "Installing git..."; \
				sudo apt update && sudo apt install -y git; \
			else \
				echo "git is already installed. Skipping."; \
			fi; \
		if ! command -v uv >/dev/null 2>&1; then \
			echo "Installing uv..."; \
			curl -LsSf https://astral.sh/uv/install.sh | sh; \
			echo "Sourcing ~/.bashrc to update shell environment..."; \
			source ~/.bashrc || true; \
			echo "Continuing even if sourcing ~/.bashrc failed..."; \
		else \
			echo "uv is already installed. Skipping."; \
		fi; \
	else \
		echo "Unsupported OS. Currently supported kernels are either Darwin (macOS) or Linux (ubuntu22.04)."; \
		exit 1; \
	fi; \

	@echo "Setting up Python..."; \
	uv python install || true; \
	echo "All tools installed successfully."

setup:
	@echo "Installing tools..."
	@{ \
		output=$$($(MAKE) install 2>&1); \
		exit_code=$$?; \
		if [ $$exit_code -ne 0 ]; then \
			echo "$$output"; \
			exit $$exit_code; \
		fi; \
	}
	@echo "All tools installed successfully."
	@echo "Setting up the project..."
	@uv sync;

	@if [ ! -d ".git" ]; then \
		echo "Setting up git..."; \
		git init -b main > /dev/null; \
	fi

	@echo "Setting up pre-commit..."
	@. .venv/bin/activate;
	@.venv/bin/pre-commit install --hook-type pre-commit --hook-type commit-msg;

clean:
	@echo "Cleaning up..."
	rm -rf .venv uv.lock
	find . -type d \
		\( -name ".pytest_cache" \
		-o -name ".mypy_cache" \
		-o -name ".ruff_cache" \
		-o -name "dist" \) \
		-exec rm -rf {} +
	@echo "Cleanup completed. Resetting terminal..."
	@reset

test:
	@echo "Running tests..."
	@uv sync;
	@uv run pytest tests --cov=src --cov-report term;

deploy_%:
	@if [ "$*" != "dev" ] && [ "$*" != "prd" ]; then \
		echo "Error: Invalid environment. Use 'dev' or 'prd'."; \
		exit 1; \
	fi
	.venv/bin/pre-commit run --all-files
	uv sync
	uv build
	@PROFILE_NAME="DEFAULT"; \
	output=$$(databricks auth env --profile "$$PROFILE_NAME" 2>&1); \
	if [[ $$output == *"Error: resolve:"* ]]; then \
		databricks configure --profile "$$PROFILE_NAME"; \
	else \
		databricks bundle deploy --profile "$$PROFILE_NAME" $$(if [ "$*" != "dev" ]; then echo "--target $*"; fi); \
	fi

destroy_%:
	@if [ "$*" != "dev" ] && [ "$*" != "prd" ]; then \
		echo "Error: Invalid environment. Use 'dev' or 'prd'."; \
		exit 1; \
	fi
	@PROFILE_NAME="DEFAULT"; \
	output=$$(databricks auth env --profile "$$PROFILE_NAME" 2>&1); \
	if [[ $$output == *"Error: resolve:"* ]]; then \
		databricks configure --profile "$$PROFILE_NAME"; \
	else \
		databricks bundle destroy --profile "$$PROFILE_NAME" --target $*; \
	fi

tree:
	@echo "Generating project tree..."
	@tree -I '.venv|__pycache__|archive|scratch|.databricks|.ruff_cache|.mypy_cache|.pytest_cache|.git|htmlcov|site|dist|.DS_Store|fixtures' -a

docs:
	@echo "Running tests and generating badges..."
	@uv run pytest -v tests --cov=src --cov-report html:docs/tests/coverage --junitxml=docs/tests/coverage/pytest_coverage.xml
	@uv run coverage xml -o docs/tests/coverage/coverage.xml
	@uv run genbadge coverage -i docs/tests/coverage/coverage.xml -o docs/assets/badge-coverage.svg
	@uv run genbadge tests -i docs/tests/coverage/pytest_coverage.xml -o docs/assets/badge-tests.svg
	@rm -rf docs/tests/coverage/.gitignore
	@echo "Generating HTML documentation..."
	@uv run pdoc --html src/unit_testing_pyspark -o docs/api --force
	@uv run pdoc --html tests -o docs/api --force
	# @uv run mkdocs build
	@uv run mkdocs serve
