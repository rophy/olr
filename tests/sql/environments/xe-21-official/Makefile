ORACLE_TARGET := xe-21-official
TESTS_DIR := $(abspath ../../..)

export DB_CONN := olr_test/olr_test@//localhost:1521/XEPDB1
export PDB_NAME := XEPDB1
export INCLUDE_TAGS := us7ascii

.PHONY: up down test-sql

up:
	docker compose up -d --wait

down:
	docker compose down

test-sql:
	cd $(TESTS_DIR) && pytest test_generate.py -v --tb=short \
		--oracle-env=$(ORACLE_TARGET) $(PYTEST_ARGS)
