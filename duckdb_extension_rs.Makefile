# Reusable makefile for the Rust extensions targeting the C extension API
#
# Inputs
#   EXTENSION_NAME : name of the extension (lower case)
#   DUCKDB_VERSION : the minimum version of DuckDB that the extension supports

.PHONY: clean test_debug test_release test debug release install_dev_dependencies all platform

#############################################
### Platform dependent config
#############################################
PYTHON_BIN=python3

ifeq ($(OS),Windows_NT)
	EXTENSION_LIB_FILENAME=$(EXTENSION_NAME).dll
	PYTHON_VENV_BIN=./venv/Scripts/python.exe
else
	PYTHON_VENV_BIN=./venv/bin/python3
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        EXTENSION_LIB_FILENAME=lib$(EXTENSION_NAME).so
    endif
    ifeq ($(UNAME_S),Darwin)
        EXTENSION_LIB_FILENAME=lib$(EXTENSION_NAME).dylib
    endif
endif

#############################################
### CI specific
#############################################

# TODO: do we need Python in Docker?
ifeq ($(LINUX_CI_IN_DOCKER),1)
    PYTHON_VENV_BIN=python3
endif

#############################################
### Main extension parameters
#############################################

# The minimum DuckDB version that this extension supports
ifeq ($(DUCKDB_VERSION),)
	DUCKDB_VERSION = v0.0.1
endif

ifeq ($(EXTENSION_VERSION),)
	EXTENSION_VERSION = v0.0.1
endif

EXTENSION_FILENAME=$(EXTENSION_NAME).duckdb_extension

#############################################
### Platform Detection
#############################################

# Write the platform we are building for
platform: build/platform

# Either autodetect or use the provided value
PLATFORM_TARGET ?=
ifeq ($(DUCKDB_PLATFORM),)
    PLATFORM_TARGET=platform_autodetect
else
	PLATFORM_TARGET=platform_override
endif

build/platform: $(PLATFORM_TARGET)

# (Don't call directly) autodetects the platform using the DuckDB installed in the venv
platform_autodetect:
	$(PYTHON_VENV_BIN) -c "from pathlib import Path;Path('./build/').mkdir(parents=True, exist_ok=True)"
	$(PYTHON_VENV_BIN) -c "import duckdb;print(duckdb.execute('pragma platform').fetchone()[0])" > build/platform.txt

# (Don't call directly) sets the platform using DUCKDB_PLATFORM variable
platform_override:
	$(PYTHON_VENV_BIN) -c "from pathlib import Path;Path('./build/').mkdir(parents=True, exist_ok=True)"
	echo $(DUCKDB_PLATFORM) > build/platform.txt

#############################################
### Development config
#############################################

# Allows overriding the duckdb-rs crates with a local version
CARGO_OVERRIDE_DUCKDB_RS_FLAG?=
ifneq ($(LOCAL_DUCKDB_RS_PATH),)
	CARGO_OVERRIDE_DUCKDB_RS_FLAG=--config 'patch.crates-io.duckdb.path="$(LOCAL_DUCKDB_RS_PATH)/crates/duckdb"' --config 'patch.crates-io.libduckdb-sys.path="$(LOCAL_DUCKDB_RS_PATH)/crates/libduckdb-sys"' --config 'patch.crates-io.duckdb-loadable-macros-sys.path="$(LOCAL_DUCKDB_RS_PATH)/crates/duckdb-loadable-macros-sys"'
endif

#############################################
### Build targets
#############################################

all: release

debug: target/debug/$(EXTENSION_FILENAME)

target/debug/$(EXTENSION_LIB_FILENAME): src/*
	cargo build $(CARGO_OVERRIDE_DUCKDB_RS_FLAG)

target/debug/$(EXTENSION_FILENAME): target/debug/$(EXTENSION_LIB_FILENAME)
	$(PYTHON_VENV_BIN) extension-ci-tools/scripts/append_extension_metadata.py \
			-l target/debug/$(EXTENSION_LIB_FILENAME) \
			-o target/debug/$(EXTENSION_FILENAME) \
			-n $(EXTENSION_NAME) \
			-dv $(DUCKDB_VERSION) \
			-ev $(EXTENSION_VERSION) \
			-pf build/platform.txt

build/debug/$(EXTENSION_FILENAME): target/debug/$(EXTENSION_LIB_FILENAME)
	$(PYTHON_VENV_BIN) -c "from pathlib import Path;Path('./build/debug/extension/$(EXTENSION_NAME)').mkdir(parents=True, exist_ok=True)"
	$(PYTHON_VENV_BIN) -c "import shutil;shutil.copyfile('target/debug/$(EXTENSION_FILENAME)', 'build/debug/$(EXTENSION_FILENAME)')"
	$(PYTHON_VENV_BIN) -c "import shutil;shutil.copyfile('target/debug/$(EXTENSION_FILENAME)', 'build/debug/extension/$(EXTENSION_NAME)/$(EXTENSION_FILENAME)')"

debug: target/debug/$(EXTENSION_FILENAME) build/debug/$(EXTENSION_FILENAME)

# RELEASE build
target/release/$(EXTENSION_LIB_FILENAME): src/*
	cargo build $(CARGO_OVERRIDE_DUCKDB_RS_FLAG) --release

target/release/$(EXTENSION_FILENAME): target/release/$(EXTENSION_LIB_FILENAME)
	$(PYTHON_VENV_BIN) extension-ci-tools/scripts/append_extension_metadata.py \
			-l target/release/$(EXTENSION_LIB_FILENAME) \
			-o target/release/$(EXTENSION_FILENAME) \
			-n $(EXTENSION_NAME) \
			-dv $(DUCKDB_VERSION) \
			-ev $(EXTENSION_VERSION) \
			-pf build/platform.txt

build/release/$(EXTENSION_FILENAME): target/release/$(EXTENSION_LIB_FILENAME)
	$(PYTHON_VENV_BIN) -c "from pathlib import Path;Path('./build/release/extension/$(EXTENSION_NAME)').mkdir(parents=True, exist_ok=True)"
	$(PYTHON_VENV_BIN) -c "import shutil;shutil.copyfile('target/release/$(EXTENSION_FILENAME)', 'build/release/$(EXTENSION_FILENAME)')"
	$(PYTHON_VENV_BIN) -c "import shutil;shutil.copyfile('target/release/$(EXTENSION_FILENAME)', 'build/release/extension/$(EXTENSION_NAME)/$(EXTENSION_FILENAME)')"

release: target/release/$(EXTENSION_FILENAME) build/release/$(EXTENSION_FILENAME)

#############################################
### Testing
#############################################

# Uncomment and add (Comma separated) names of core extensions that are required to run your tests
EXTRA_EXTENSIONS_PARAM=--preinstall-extensions icu,aws,json,vss

# Note: to override the default test runner, create a symlink to a different venv
TEST_RUNNER=$(PYTHON_VENV_BIN) -m duckdb_sqllogictest

TEST_RUNNER_BASE=$(TEST_RUNNER) --test-dir test/sql $(EXTRA_EXTENSIONS_PARAM)
TEST_RUNNER_DEBUG=$(TEST_RUNNER_BASE) --external-extension target/debug/rusty_quack.duckdb_extension
TEST_RUNNER_RELEASE=$(TEST_RUNNER_BASE) --external-extension target/release/rusty_quack.duckdb_extension

# By default latest duckdb is installed, set DUCKDB_TEST_VERSION to switch to a different version
DUCKDB_INSTALL_VERSION?=
ifneq ($(DUCKDB_TEST_VERSION),)
	DUCKDB_INSTALL_VERSION===$(DUCKDB_TEST_VERSION)
endif

# TODO: I'm not 100% this is correct right now: we have a test version and a minimum target version: these are independent-ish
ifneq ($(DUCKDB_GIT_VERSION),)
	DUCKDB_INSTALL_VERSION===$(DUCKDB_GIT_VERSION)
endif

# Main tests
test: test_release

TEST_RELEASE_TARGET=test_release_internal
TEST_DEBUG_TARGET=test_debug_internal
TEST_RELDEBUG_TARGET=test_reldebug_internal

# Disable testing outside docker: the unittester is currently dynamically linked by default
ifeq ($(LINUX_CI_IN_DOCKER),1)
	SKIP_TESTS=1
endif

ifeq ($(DUCKDB_PLATFORM),linux_amd64_gcc4)
	SKIP_TESTS=1
endif

ifeq ($(SKIP_TESTS),1)
	TEST_RELEASE_TARGET=tests_skipped
	TEST_DEBUG_TARGET=tests_skipped
endif

test_release: $(TEST_RELEASE_TARGET)
test_debug: $(TEST_DEBUG_TARGET)

test_release_internal:
	@echo "Running RELEASE tests.."
	@$(TEST_RUNNER_RELEASE)
test_debug_internal:
	@echo "Running DEBUG tests.."
	@$(TEST_RUNNER_DEBUG)

tests_skipped:
	@echo "Skipping tests.."

clean:
	cargo clean
	rm -rf build
	rm -rf duckdb_unittest_tempdir
	rm -rf venv

nop:
	@echo "NOP"

set_duckdb_version: nop

set_duckdb_tag: nop

output_distribution_matrix:
	cat extension-ci-tools/config/distribution_matrix.json

#############################################
### Python
#############################################

# Installs the test runner using the selected DuckDB version (latest stable by default)
# TODO: switch to PyPI distribution
venv:
	$(PYTHON_BIN) -m venv venv
	$(PYTHON_VENV_BIN) -m pip install 'duckdb$(DUCKDB_INSTALL_VERSION)'
	$(PYTHON_VENV_BIN) -m pip install git+https://github.com/duckdb/duckdb-sqllogictest-python

#############################################
### Configure
#############################################

configure: venv platform

CONFIGURE_CI_STEP?=
ifeq ($(LINUX_CI_IN_DOCKER),1)
	CONFIGURE_CI_STEP=nop
else
	CONFIGURE_CI_STEP=configure
endif

configure_ci: $(CONFIGURE_CI_STEP)
