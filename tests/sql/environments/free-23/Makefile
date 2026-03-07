ORACLE_TARGET := free-23
SQL_DIR := $(abspath ../..)
SCRIPTS_DIR := $(SQL_DIR)/scripts
INPUTS_DIR := $(SQL_DIR)/inputs
# Discover scenarios: both single .sql files and directories with test.sql
SCENARIOS := $(sort \
    $(patsubst $(INPUTS_DIR)/%.sql,%,$(wildcard $(INPUTS_DIR)/*.sql)) \
    $(patsubst $(INPUTS_DIR)/%/test.sql,%,$(wildcard $(INPUTS_DIR)/*/test.sql)))
SCENARIO ?=

.PHONY: up down test-sql

up:
	docker compose up -d --wait

down:
	docker compose down

test-sql:
ifdef SCENARIO
	ORACLE_TARGET=$(ORACLE_TARGET) $(SCRIPTS_DIR)/generate.sh $(SCENARIO)
else
	@for name in $(SCENARIOS); do \
		echo "=== Generating: $$name ==="; \
		ORACLE_TARGET=$(ORACLE_TARGET) $(SCRIPTS_DIR)/generate.sh "$$name" || exit 1; \
	done
endif
