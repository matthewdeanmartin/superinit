# Variables
SHELLCHECK := "shellcheck"
BATS := "bats"
BPkg := "bpkg"

# Directories
SRC_DIR := "."
TEST_DIR := "tests"

# Tasks
# Dependency installation tasks
install_deps:
    @echo "Installing dependencies with bpkg..."
    @$(BPkg) install -g shellcheck || echo "shellcheck already installed"
    @$(BPkg) install -g bats-core/bats-core || echo "bats already installed"

# install_bpkg:
#    @echo "Installing bpkg..."
#    @curl -sLo- "https://get.bpkg.sh" | bash

pipx_installs:
    @echo "Installing pipx packages..."
    pipx install shelldoc
    pipx install md-to-html

winget_installs:
    @echo "Installing winget packages..."
    winget install jqlang.jq
    winget install --id koalaman.shellcheck

npm_installs:
    @echo "Installing npm packages..."
    npm install -g bats

go_installs:
    @echo "Installing go packages..."
    go install mvdan.cc/sh/v3/cmd/shfmt@latest

# Formatting task
format:
    @echo "Formatting scripts..."
    shfmt -l -w *.sh

# Cleaning task
clean:
    @echo "Cleaning up..."
    rm -rf {{TEST_DIR}}/tmp

# Quality control tasks
lint:
    @echo "Running shellcheck on all scripts..."
    {{SHELLCHECK}} -x {{SRC_DIR}}/*.sh

test:
    @echo "Running bats tests..."
    {{BATS}} {{TEST_DIR}}

# Documentation tasks
docs:
    @shelldoc -f *.sh
    @for FILE in ./docs/*.md; do md-to-html --input "$FILE" --output "$FILE".html; done

open_docs:
    @if [ "$$(uname)" = "Linux" ]; then \
        xdg-open ./docs/*.html; \
    elif [ "$$(uname)" = "Darwin" ]; then \
        open ./docs/*.html; \
    elif [ "$$(uname | grep -i 'mingw\\|msys\\|cygwin')" ]; then \
        start ./docs/*.html; \
    else \
        echo "Unsupported OS"; \
    fi

check: format lint test docs
    @echo "Running all checks..."

# Suggested additional tasks install_bpkg
install_all: pipx_installs winget_installs npm_installs go_installs
    @echo "Installed all necessary tools."

validate_dependencies:
    @echo "Validating if all dependencies are installed correctly..."
    command -v shellcheck || echo "Shellcheck not installed"
    command -v bats || echo "Bats not installed"

watch_tests:
    @echo "Watching for file changes and running tests..."
    find . -name "*.sh" | entr just test

update_tools:
    @echo "Updating all installed tools..."
    pipx upgrade shelldoc
    pipx upgrade md-to-html
    go get -u mvdan.cc/sh/v3/cmd/shfmt
