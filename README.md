# DuckDB Rust extension template
This is an experimental template for Rust based extensions based on the C Extension API of DuckDB.

## Building
Building is simple just ensure Rust is installed, then run
```shell
make debug
```
or
```shell
make release
```

## Testing
This extension uses the DuckDB Python client. This client ships with a test runner.

### Step 1
- creates a local python3 venv
- installs DuckDB into the venv
- installs the test extension dependencies by running `install_test_dependencies.py`
```sh
make install_test_dependencies
```
Alternatively, a specific duckdb version can be chosen
```shell
DUCKDB_TEST_VERSION=v1.0.0 make install_test_dependencies
```

### Step 2
Run the tests!

```shell
make test_debug
```
or 
```shell
make test_release
```