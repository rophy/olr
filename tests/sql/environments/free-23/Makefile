ORACLE_TARGET := free-23
TESTS_DIR := $(abspath ../../..)

.PHONY: up down test-sql

up:
	docker compose up -d --wait

down:
	docker compose down

test-sql:
	cd $(TESTS_DIR) && pytest test_generate.py -v --tb=short \
		--oracle-env=$(ORACLE_TARGET) $(PYTEST_ARGS)
