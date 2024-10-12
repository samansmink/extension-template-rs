.PHONY: clean test_debug test_release test debug release install_test_dependencies all clean_test_dependencies

PROJ_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

### Extension metadata params
DUCKDB_PLATFORM=osx_arm64
DUCKDB_VERSION=v0.0.1
EXTENSION_VERSION=v0.0.1
EXTENSION_NAME=rusty_quack

ifneq ($(DUCKDB_EXPLICIT_PLATFORM),)
	DUCKDB_PLATFORM = $(DUCKDB_EXPLICIT_PLATFORM)
endif
ifneq ($(DUCKDB_EXPLICIT_VERSION),)
	DUCKDB_VERSION = $(DUCKDB_EXPLICIT_VERSION)
endif
ifneq ($(EXPLICIT_EXTENSION_VERSION),)
	EXTENSION_VERSION = $(EXPLICIT_EXTENSION_VERSION)
endif

# TODO make platform independent
EXTENSION_LIB_FILENAME=lib$(EXTENSION_NAME).dylib
EXTENSION_FILENAME=$(EXTENSION_NAME).duckdb_extension

### Development options
CARGO_OVERRIDE_DUCKDB_RS_FLAG?=
ifneq ($(LOCAL_DUCKDB_RS_PATH),)
	CARGO_OVERRIDE_DUCKDB_RS_FLAG=--config 'patch.crates-io.duckdb.path="$(LOCAL_DUCKDB_RS_PATH)/crates/duckdb"' --config 'patch.crates-io.libduckdb-sys.path="$(LOCAL_DUCKDB_RS_PATH)/crates/libduckdb-sys"' --config 'patch.crates-io.duckdb-loadable-macros-sys.path="$(LOCAL_DUCKDB_RS_PATH)/crates/duckdb-loadable-macros-sys"'
endif

all: release

# DEBUG build
debug: target/debug/$(EXTENSION_FILENAME)

target/debug/$(EXTENSION_LIB_FILENAME): src/*
	cargo build $(CARGO_OVERRIDE_DUCKDB_RS_FLAG)

target/debug/$(EXTENSION_FILENAME): target/debug/$(EXTENSION_LIB_FILENAME)
	python3 extension-ci-tools/scripts/append_extension_metadata.py \
			-l target/debug/$(EXTENSION_LIB_FILENAME) \
			-o target/debug/$(EXTENSION_FILENAME) \
			-n $(EXTENSION_NAME) \
			-dv $(DUCKDB_VERSION) \
			-ev $(EXTENSION_VERSION) \
			-p $(DUCKDB_PLATFORM)

build/debug/$(EXTENSION_FILENAME): target/debug/$(EXTENSION_LIB_FILENAME)
	mkdir -p build/debug
	cp target/debug/$(EXTENSION_LIB_FILENAME) build/debug/$(EXTENSION_FILENAME)

debug: target/debug/$(EXTENSION_FILENAME) build/debug/$(EXTENSION_FILENAME)

# RELEASE build
target/release/$(EXTENSION_LIB_FILENAME): src/*
	cargo build $(CARGO_OVERRIDE_DUCKDB_RS_FLAG) --release

target/release/$(EXTENSION_FILENAME): target/release/$(EXTENSION_LIB_FILENAME)
	python3 extension-ci-tools/scripts/append_extension_metadata.py \
			-l target/release/$(EXTENSION_LIB_FILENAME) \
			-o target/release/$(EXTENSION_FILENAME) \
			-n $(EXTENSION_NAME) \
			-dv $(DUCKDB_VERSION) \
			-ev $(EXTENSION_VERSION) \
			-p $(DUCKDB_PLATFORM)

build/release/$(EXTENSION_FILENAME): target/release/$(EXTENSION_LIB_FILENAME)
	mkdir -p build/release
	cp target/release/$(EXTENSION_LIB_FILENAME) build/release/$(EXTENSION_FILENAME)

release: target/release/$(EXTENSION_FILENAME) build/release/$(EXTENSION_FILENAME)

### Test options

# Uncomment and add (Comma separated) names of core extensions that are required to run your tests
EXTRA_EXTENSIONS_PARAM=--preinstall-extensions icu,aws,json,vss

# Note: to override the default test runner, create a symlink to a different venv
TEST_RUNNER=./venv/bin/python3 -m duckdb_sqllogictest

TEST_RUNNER_BASE=$(TEST_RUNNER) --test-dir test/sql $(EXTRA_EXTENSIONS_PARAM)
TEST_RUNNER_DEBUG=$(TEST_RUNNER_BASE) --external-extension target/debug/rusty_quack.duckdb_extension
TEST_RUNNER_RELEASE=$(TEST_RUNNER_BASE) --external-extension target/release/rusty_quack.duckdb_extension

# By default latest duckdb is installed, set DUCKDB_TEST_VERSION to switch to a different version
DUCKDB_INSTALL_VERSION?=
ifneq ($(DUCKDB_TEST_VERSION),)
	DUCKDB_INSTALL_VERSION===$(DUCKDB_TEST_VERSION)
endif

# Installs the test runner using the selected DuckDB version (latest stable by default)
install_test_dependencies:
	rm -rf venv
	python3 -m venv venv
	./venv/bin/python3 -m pip install 'duckdb$(DUCKDB_INSTALL_VERSION)'
	./venv/bin/python3 -m pip install  git+https://github.com/duckdb/duckdb-sqllogictest-python # TODO: replace with pypi package

test_debug: debug
	@echo "Running DEBUG tests.."
	@$(TEST_RUNNER_DEBUG)

test: test_debug

test_release: release
	@echo "Running RELEASE tests.."
	@$(TEST_RUNNER_RELEASE)

clean:
	cargo clean
	rm -rf build
	rm -rf duckdb_unittest_tempdir

clean_test_dependencies:
	rm -rf venv
