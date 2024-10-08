PROJ_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

### Extension metadata params
DUCKDB_PLATFORM=osx_arm64
DUCKDB_VERSION=v0.0.1
EXTENSION_VERSION=v0.0.1

ifneq ($(DUCKDB_EXPLICIT_PLATFORM),)
	DUCKDB_PLATFORM = $(DUCKDB_EXPLICIT_PLATFORM)
endif
ifneq ($(DUCKDB_EXPLICIT_VERSION),)
	DUCKDB_VERSION = $(DUCKDB_EXPLICIT_VERSION)
endif
ifneq ($(EXPLICIT_EXTENSION_VERSION),)
	EXTENSION_VERSION = $(EXPLICIT_EXTENSION_VERSION)
endif

### Development options
CARGO_OVERRIDE_DUCKDB_RS_FLAG?=
ifneq ($(LOCAL_DUCKDB_RS_PATH),)
	CARGO_OVERRIDE_DUCKDB_RS_FLAG=--config 'patch.crates-io.duckdb.path="$(LOCAL_DUCKDB_RS_PATH)/crates/duckdb"' --config 'patch.crates-io.libduckdb-sys.path="$(LOCAL_DUCKDB_RS_PATH)/crates/libduckdb-sys"' --config 'patch.crates-io.duckdb-loadable-macros-sys.path="$(LOCAL_DUCKDB_RS_PATH)/crates/duckdb-loadable-macros-sys"'
endif

debug_lib:
	cargo build $(CARGO_OVERRIDE_DUCKDB_RS_FLAG)

debug: debug_lib
	python3 extension-ci-tools/scripts/append_extension_metadata.py \
			-l target/debug/librusty_quack.dylib \
			-o target/debug/rusty_quack.duckdb_extension \
			-n rusty_quack \
			-dv $(DUCKDB_VERSION) \
			-ev $(EXTENSION_VERSION) \
			-p $(DUCKDB_PLATFORM)

release_lib:
	cargo build --release $(CARGO_OVERRIDE_DUCKDB_RS_FLAG)

release: release_lib
	python3 extension-ci-tools/scripts/append_extension_metadata.py \
			-l target/release/librusty_quack.dylib \
			-o target/release/rusty_quack.duckdb_extension \
			-n rusty_quack \
			-dv $(DUCKDB_VERSION) \
			-ev $(EXTENSION_VERSION) \
			-p $(DUCKDB_PLATFORM)

### Test options

# this param is passed to the tester which will ensure these are installed
# EXTRA_EXTENSIONS_PARAM=--preinstall-extensions json,icu TODO: enable once tester is distributed

# Note: to override the default test runner, create a symlink to a different venv
TEST_RUNNER=./venv/bin/python3 -m duckdb.sqllogictest

TEST_RUNNER_BASE=$(TEST_RUNNER) --test-dir test/sql $(EXTRA_EXTENSIONS_PARAM)
TEST_RUNNER_DEBUG=$(TEST_RUNNER_BASE) --external-extension target/debug/rusty_quack.duckdb_extension
TEST_RUNNER_RELEASE=$(TEST_RUNNER_BASE) --external-extension target/release/rusty_quack.duckdb_extension

# By default latest duckdb is installed, set DUCKDB_TEST_VERSION to switch to a different version
DUCKDB_INSTALL_VERSION?=
ifneq ($(DUCKDB_TEST_VERSION),)
	DUCKDB_INSTALL_VERSION===$(DUCKDB_TEST_VERSION)
endif

# Installs the test runner (and duckdb itself)
install_test_dependencies:
	#TODO: enable once tester is distributed
	ln -sf ../duckdb/venv venv
#	 python3 -m venv venv
#	./venv/bin/pip3 install 'duckdb$(DUCKDB_INSTALL_VERSION)'
#	./venv/bin/python3 install_test_dependencies.py

test_debug:
	$(TEST_RUNNER_DEBUG)

test_release:
	$(TEST_RUNNER_RELEASE)

clean:
	cargo clean

