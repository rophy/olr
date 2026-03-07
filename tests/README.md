# OpenLogReplicator Test Framework

Automated regression testing for OpenLogReplicator. Each test runs OLR in batch
mode against captured Oracle redo logs and compares JSON output against golden
files validated by Oracle LogMiner.

## Prerequisites

- Docker with Compose v2
- Python 3.6+ (stdlib only, no pip dependencies)
- Bash

No C++ toolchain needed on the host — OLR is built inside Docker.

## Quick Start

```bash
# Build OLR Docker image (includes binary + gtest)
make build

# Run regression tests against pre-captured fixtures
make test-redo

# Generate fixtures for a specific Oracle environment
make -C tests/sql/environments/free-23 up
make -C tests/sql/environments/free-23 test-sql

# Generate a single fixture
make -C tests/sql/environments/free-23 test-sql SCENARIO=basic-crud

# Cleanup
make -C tests/sql/environments/free-23 down
make clean
```

## How It Works

### Regression Tests (`make test-redo`)

Runs `ctest` inside the `olr-dev` Docker image with the `tests/` directory
mounted. The C++ test runner (`test_pipeline.cpp`) auto-discovers fixtures from
two locations:

- `tests/fixtures/expected/*/output.json` — committed golden files
- `tests/sql/generated/expected/*/output.json` — locally generated fixtures

For each fixture it builds a batch-mode OLR config, runs OLR, and compares
output line-by-line against the golden file. No Oracle instance needed.

### Fixture Generation (`make test-sql`)

The `sql/scripts/generate.sh` script runs 7 stages per scenario:

| Stage | Action |
|-------|--------|
| 0 | (DDL only) Build LogMiner dictionary into redo logs |
| 1 | Run SQL scenario against Oracle, capture start/end SCN |
| 2 | Force log switches, copy archived redo logs |
| 3 | Generate schema checkpoint via `gencfg.sql` |
| 4 | Run LogMiner, convert output to JSON |
| 5 | Run OLR in batch mode against captured redo logs |
| 6 | Compare OLR output vs LogMiner — **fail if mismatch** |
| 7 | Save OLR output as golden file to `sql/generated/` |

## Directory Structure

```
tests/
  CMakeLists.txt                    # gtest build config
  test_pipeline.cpp                 # Parameterized gtest runner
  README.md

  fixtures/                         # Committed golden fixtures (self-contained, no Oracle needed)
    expected/<scenario>/output.json
    schema/<scenario>/TEST-chkpt-<scn>.json
    redo/<scenario>/*.dbf

  sql/                              # SQL test infrastructure (requires live Oracle)
    inputs/                         # SQL scenarios
      basic-crud.sql                # Single-file format
      example/                      # Split format (setup.sql + test.sql)
        setup.sql
        test.sql
    environments/                   # Oracle container environments
      free-23/                      # Oracle Free 23c
      xe-21/                        # Oracle XE 21c
      xe-21-official/               # Oracle XE 21c (official image, supports charset)
    scripts/
      generate.sh                   # Generate + validate one fixture (all topologies)
      compare.py                    # OLR vs LogMiner comparison
      logminer2json.py              # LogMiner spool → JSON converter
      drivers/
        base.sh                     # Base driver: stage functions + primitive stubs
        docker.sh                   # Default: docker exec + compose exec
        local.sh                    # Local Oracle + local OLR binary
        rac.sh                      # RAC: SSH + podman exec to RAC VM
      oracle-init/
        01-setup.sh                 # Enables archivelog + supplemental logging
    generated/                      # Locally generated fixtures (gitignored)

  .work/                            # Temporary generation working dirs (gitignored)
```

## Input Formats

Scenarios support two input formats:

### Single-file (`inputs/example.sql`)

Self-contained SQL with setup, SCN markers, DML, and EXIT. Redo logs include
all activity (setup DDL + DML).

### Split directory (`inputs/example/`)

- `setup.sql` — DDL (optional). Run before a log switch.
- `test.sql` — DML only (required). Pure SQL, no boilerplate needed.

The framework handles SQL*Plus settings, SCN capture, and log switches
automatically. Redo logs contain only the DML, making them much smaller —
ideal for fixtures committed to version control.

**Conflict check:** Having both `inputs/example.sql` and `inputs/example/`
is an error.

## Writing New Scenarios

### Single-file format

Create a SQL file in `sql/inputs/` that:

1. Creates test table(s) with supplemental logging
2. Records start SCN via `DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || scn)`
3. Performs DML operations with explicit COMMITs
4. Ends with `EXIT`

See `sql/inputs/basic-crud.sql` for the template.

### Split format

Create a directory in `sql/inputs/` with:

- `setup.sql` — table creation, supplemental logging (optional)
- `test.sql` — DML only

See `sql/inputs/example/` for a minimal example.

**Note:** Log switches are handled by `generate.sh` — don't add
`ALTER SYSTEM SWITCH LOGFILE` to scenario SQL.

### Scenario Annotations

Annotations are comments in scenario SQL files that modify generation behaviour:

| Annotation | Effect |
|------------|--------|
| `-- @DDL` | Switches LogMiner to `DICT_FROM_REDO_LOGS + DDL_DICT_TRACKING` so schema changes are tracked inline |
| `-- @MID_SWITCH` | Triggers a log switch mid-execution (one per marker). Use with `DBMS_SESSION.SLEEP()` at that point. |
| `-- @TAG <name>` | Marks the scenario as opt-in. Skipped unless `INCLUDE_TAGS=<name>` is set. |

**Tag filtering:**

```bash
# Only run scenarios tagged "us7ascii"
INCLUDE_TAGS=us7ascii make -C tests/sql/environments/xe-21-official test-sql

# Run all scenarios except those tagged "slow"
EXCLUDE_TAGS=slow make -C tests/sql/environments/free-23 test-sql
```

### DDL Scenarios

Add `-- @DDL` at the top. See `sql/inputs/ddl-add-column.sql` for an example.

### Long-Spanning Transactions

Add `-- @MID_SWITCH` markers where log switches should occur during execution.
See `sql/inputs/long-spanning-txn.sql` for an example.

### RAC Scenarios

RAC multi-thread scenarios use `.rac.sql` files with a block-based format.
Generate with `ORACLE_DRIVER=rac` against a live Oracle RAC VM.

## Oracle Drivers

`generate.sh` supports pluggable drivers via `ORACLE_DRIVER` (default: `docker`).

| Driver | How Oracle is accessed | How OLR runs |
|--------|----------------------|--------------|
| `docker` | `docker exec` into Oracle container | `docker compose exec olr` |
| `local` | Local `sqlplus` binary | Local `OLR_BINARY` |
| `rac` | SSH to RAC VM + `podman exec` | `docker run` with OLR image |

## CI Workflows

### `sql-tests-free23.yaml` / `sql-tests-xe21.yaml`

Triggered on push to master (or manually). Starts Oracle, generates all
fixtures with LogMiner validation, uploads as artifact (90-day retention).

### `redo-log-tests.yaml`

Triggered on push/PR to master. Builds the OLR image, downloads the latest
fixture artifacts from the SQL test workflows, and runs `ctest` inside Docker.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ORACLE_DRIVER` | `docker` | Driver to use: `docker`, `local`, or `rac` |
| `ORACLE_TARGET` | `free-23` | Environment name (matches `sql/environments/` subdir) |
| `ORACLE_CONTAINER` | `oracle` | Docker container name for Oracle (docker driver) |
| `DB_CONN` | `olr_test/olr_test@//localhost:1521/FREEPDB1` | Test user connect string |
| `SCHEMA_OWNER` | `OLR_TEST` | Schema owner for LogMiner filter |
| `PDB_NAME` | `FREEPDB1` | PDB name for schema generation |
| `OUTPUT_BASE` | `tests/sql/generated` | Output directory for generated fixtures |
| `INCLUDE_TAGS` | — | Space-separated tags; only run matching scenarios |
| `EXCLUDE_TAGS` | — | Space-separated tags; skip matching scenarios |
