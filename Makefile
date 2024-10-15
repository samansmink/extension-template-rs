PROJ_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

EXTENSION_NAME=rusty_quack

include duckdb_extension_rs.Makefile

