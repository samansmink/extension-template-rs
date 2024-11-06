# DuckDB Rust extension template
This is an experimental template for Rust based extensions based on the C Extension API of DuckDB.

## Cloning

Clone the repo with submodules

```shell
git clone --recurse-submodules <repo>
```

## Venv

This template assumes you are using a venv called `venv`. If you are using uv, 

```shell
uv venv venv
source venv/bin/activate
```

## Building
Building is simple just ensure Rust is installed, then run
```shell
make configure
```

```shell
make debug
```
or
```shell
make release
```

### Dependencies
In essence, this extension only requires Cargo to compile.

However, to make life as a developer a bit easier, this extension relies on a combination of Make, Python 3 and Pip to ease the
building and testing process.

## Testing
This extension uses the DuckDB Python client for testing

The `make configure` step will automatically install DuckDB. This means that after running `make configure` and `make debug`, running the 
tests is as simple as `make test_debug`.

To test your extension against 

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

### Known issues
This is a bit of a footgun, but the extensions produced by this template may (or may not) be broken on windows on python3.11 
with the following error on extension load:
```shell
IO Error: Extension '<name>.duckdb_extension' could not be loaded: The specified module could not be found
```
This was resolved by using python 3.12