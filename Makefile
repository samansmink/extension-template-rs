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
# TODO: this currently does not seem to work due to DuckDB-rs 1.1 not being published yet
CARGO_OVERRIDE_DUCKDB_RS_FLAG?=
ifneq ($(LOCAL_DUCKDB_RS_PATH),)
	CARGO_OVERRIDE_DUCKDB_RS_FLAG=--config 'patch.crates-io.duckdb.path="$(LOCAL_DUCKDB_RS_PATH)/crates/duckdb"' --config 'patch.crates-io.libduckdb-sys.path="$(LOCAL_DUCKDB_RS_PATH)/crates/libduckdb-sys"' --config 'patch.crates-io.duckdb-loadable-macros-sys.path="$(LOCAL_DUCKDB_RS_PATH)/crates/duckdb-loadable-macros-sys"'
endif

debug:
	cargo build $(CARGO_OVERRIDE_DUCKDB_RS_FLAG)
	python3 extension-ci-tools/scripts/append_extension_metadata.py \
			-l target/debug/librusty_quack.dylib \
			-o target/debug/rusty_quack.duckdb_extension \
			-n rusty_quack \
			-dv $(DUCKDB_VERSION) \
			-ev $(EXTENSION_VERSION) \
			-p $(DUCKDB_PLATFORM)

release:
	cargo build --release $(CARGO_OVERRIDE_DUCKDB_RS_FLAG)
	python3 extension-ci-tools/scripts/append_extension_metadata.py \
			-l target/release/librusty_quack.dylib \
			-o target/release/rusty_quack.duckdb_extension \
			-n rusty_quack \
			-dv $(DUCKDB_VERSION) \
			-ev $(EXTENSION_VERSION) \
			-p $(DUCKDB_PLATFORM)

clean:
	cargo clean
