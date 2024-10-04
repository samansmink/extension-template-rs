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
TEST_RUNNER_DEFAULT=echo "\nplease set DUCKDB_UNITTEST_BINARY to run tests"
TEST_PARAMETERS=--test-dir $(PROJ_DIR) "test/sql/*"
ifneq ($(DUCKDB_UNITTEST_BINARY),)
	TEST_RUNNER_DEBUG=$(DUCKDB_UNITTEST_BINARY) --external-extension $(PROJ_DIR)target/debug/rusty_quack.duckdb_extension $(TEST_PARAMETERS)
	TEST_RUNNER_RELEASE=$(DUCKDB_UNITTEST_BINARY) --external-extension $(PROJ_DIR)target/debug/rusty_quack.duckdb_extension $(TEST_PARAMETERS)
else
	TEST_RUNNER_DEBUG=$(TEST_RUNNER_DEFAULT)
	TEST_RUNNER_RELEASE=$(TEST_RUNNER_DEFAULT)
endif

test_debug:
	$(TEST_RUNNER_DEBUG)

test_release:
	$(TEST_RUNNER_RELEASE)

clean:
	cargo clean
