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
make -C tests/1-environments/free-23 up
make -C tests/1-environments/free-23 test-sql

# Generate a single fixture
make -C tests/1-environments/free-23 test-sql SCENARIO=basic-crud

# Cleanup
make -C tests/1-environments/free-23 down
make clean
```

## How It Works

### Regression Tests (`make test-redo`)

Runs `ctest` inside the `olr-dev` Docker image with the `tests/` directory
mounted. The C++ test runner (`test_pipeline.cpp`) auto-discovers fixtures from
two locations:

- `tests/2-prebuilt/expected/*/output.json` — committed golden files
- `tests/3-generated/expected/*/output.json` — locally generated fixtures

For each fixture it builds a batch-mode OLR config, runs OLR, and compares
output line-by-line against the golden file. No Oracle instance needed.

### Fixture Generation (`make test-sql`)

The `scripts/generate.sh` script runs 7 stages per scenario:

| Stage | Action |
|-------|--------|
| 0 | (DDL only) Build LogMiner dictionary into redo logs |
| 1 | Run SQL scenario against Oracle, capture start/end SCN |
| 2 | Force log switches, copy archived redo logs |
| 3 | Generate schema checkpoint via `gencfg.sql` |
| 4 | Run LogMiner, convert output to JSON |
| 5 | Run OLR in batch mode against captured redo logs |
| 6 | Compare OLR output vs LogMiner — **fail if mismatch** |
| 7 | Save OLR output as golden file to `3-generated/` |

## Directory Structure

```
tests/
  CMakeLists.txt                    # gtest build config
  test_pipeline.cpp                 # Parameterized gtest runner
  README.md
  0-inputs/                         # SQL scenarios (committed)
    basic-crud.sql
    data-types.sql
    ...
    rac-interleaved.rac.sql         # RAC multi-thread scenarios (@TAG rac)
    ...
  1-environments/                   # Oracle container environments
    free-23/                        # Oracle Free 23c
    xe-21/                          # Oracle XE 21c
    xe-21-official/                 # Oracle XE 21c (official image, supports charset)
  2-prebuilt/                       # Committed golden fixtures
    expected/<scenario>/output.json
    schema/<scenario>/TEST-chkpt-<scn>.json
    redo/<scenario>/*.arc           # gitignored (large binary)
  3-generated/                      # Locally generated fixtures (gitignored)
    expected/
    schema/
    redo/
  scripts/
    generate.sh                     # Generate + validate one fixture (all topologies)
    compare.py                      # OLR vs LogMiner comparison
    logminer2json.py                # LogMiner spool → JSON converter
    drivers/
      base.sh                       # Base driver: stage functions + primitive stubs
      docker.sh                     # Default: docker exec + compose exec
      local.sh                      # Local Oracle + local OLR binary
      rac.sh                        # RAC: SSH + podman exec to RAC VM
    oracle-init/
      01-setup.sh                   # Enables archivelog + supplemental logging
  .work/                            # Temporary generation working dirs (gitignored)
```

Only `0-inputs/`, `1-environments/`, `2-prebuilt/expected/`, `2-prebuilt/schema/`,
`scripts/`, and build files are committed. Redo logs and `3-generated/` are
gitignored and distributed as CI artifacts.

## Writing New Scenarios

Create a SQL file in `0-inputs/` that:

1. Creates test table(s) with supplemental logging
2. Records start SCN via `DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || scn)`
3. Performs DML operations with explicit COMMITs
4. Records end SCN via `DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_END: ' || scn)`
5. Ends with `EXIT`

See `0-inputs/basic-crud.sql` for the template.

**Note:** Log switches are handled by `generate.sh` — don't add
`ALTER SYSTEM SWITCH LOGFILE` to scenario SQL.

### Scenario Annotations

Annotations are comments at the top of a `.sql` file that modify generation
behaviour:

| Annotation | Effect |
|------------|--------|
| `-- @DDL` | Switches LogMiner to `DICT_FROM_REDO_LOGS + DDL_DICT_TRACKING` so schema changes are tracked inline |
| `-- @MID_SWITCH` | Triggers a log switch mid-execution (one per marker). Use with `DBMS_SESSION.SLEEP()` at that point. Useful for transactions spanning multiple archive logs. |
| `-- @TAG <name>` | Marks the scenario as opt-in. Skipped unless `INCLUDE_TAGS=<name>` is set. Can appear multiple times for multiple tags. |

**Tag filtering** is controlled by two environment variables:

```bash
# Only run scenarios tagged "us7ascii"
INCLUDE_TAGS=us7ascii make -C tests/1-environments/xe-21-official test-sql

# Run all scenarios except those tagged "slow"
EXCLUDE_TAGS=slow make -C tests/1-environments/free-23 test-sql
```

The `rac` tag is used for `.rac.sql` scenarios that require the `rac` driver
(`ORACLE_DRIVER=rac`) and a live RAC VM — they are automatically skipped in
standard workflows.

### DDL Scenarios

Add `-- @DDL` at the top. See `0-inputs/ddl-add-column.sql` for an example.

### Long-Spanning Transactions

Add `-- @MID_SWITCH` markers where log switches should occur during execution.
The SQL should use `DBMS_SESSION.SLEEP()` at those points.
See `0-inputs/long-spanning-txn.sql` for an example.

### RAC Scenarios

RAC multi-thread scenarios use `.rac.sql` files with a block-based format:

```sql
-- @TAG rac
-- @SETUP  — table creation, supplemental logging, SCN capture (runs on node 1)
-- @NODE1  — DML executed on node 1
-- @NODE2  — DML executed on node 2
```

Multiple `@NODE1`/`@NODE2` blocks are supported and executed in order.
Generate with `ORACLE_DRIVER=rac ./scripts/generate.sh` against a live Oracle RAC VM.

## Oracle Drivers

`generate.sh` supports pluggable drivers via `ORACLE_DRIVER` (default: `docker`).

| Driver | How Oracle is accessed | How OLR runs |
|--------|----------------------|--------------|
| `docker` | `docker exec` into Oracle container | `docker compose exec olr` |
| `local` | Local `sqlplus` binary | Local `OLR_BINARY` |
| `rac` | SSH to RAC VM + `podman exec` | `docker run` with OLR image |

```bash
# Use local Oracle and local OLR binary
ORACLE_DRIVER=local \
OLR_BINARY=/opt/OpenLogReplicator/OpenLogReplicator \
DB_CONN=olr_test/olr_test@//localhost:1521/FREEPDB1 \
  ./scripts/generate.sh basic-crud
```

Custom drivers can be added as `scripts/drivers/<name>.sh`. Each driver sources
`base.sh` and overrides primitives: `_exec_sysdba`, `_exec_user`,
`_oracle_spool_path`, `_fetch_spool`, `_fetch_archive`, `_olr_path`,
`_run_olr_cmd`. Drivers can also override stage functions and set variables
like `SWITCH_LOGFILE_SQL`, `ARCHIVE_LOG_VIEW`, `FIXTURE_SUFFIX`.

## Comparison Details

The comparison tool (`scripts/compare.py`) handles:

- **Content-based matching**: pairs records by operation type, table, and column
  values rather than strict ordering (LogMiner orders by redo SCN, OLR by
  commit SCN)
- **Type tolerance**: `"100"` matches `100`, float precision differences allowed
- **Date/timestamp conversion**: Oracle format strings vs epoch seconds
- **LOB merging**: Oracle splits LOB writes into INSERT(EMPTY_CLOB) + UPDATE;
  these are merged to match OLR's coalesced output
- **Supplemental log columns**: OLR includes all columns via supplemental
  logging; extra columns beyond what LogMiner shows are allowed

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
| `ORACLE_TARGET` | `free-23` | Environment name (matches `1-environments/` subdir) |
| `ORACLE_CONTAINER` | `oracle` | Docker container name for Oracle (docker driver) |
| `DOCKER_EXEC_USER` | — | User for `docker exec` (set to `oracle` for official images) |
| `DB_CONN` | `olr_test/olr_test@//localhost:1521/FREEPDB1` | Test user connect string |
| `SCHEMA_OWNER` | `OLR_TEST` | Schema owner for LogMiner filter |
| `PDB_NAME` | `FREEPDB1` | PDB name for schema generation |
| `OLR_BINARY` | — | Path to OLR binary (required for `local` driver) |
| `OUTPUT_BASE` | `tests/3-generated` | Output directory for generated fixtures |
| `INCLUDE_TAGS` | — | Space-separated tags; only run matching scenarios |
| `EXCLUDE_TAGS` | — | Space-separated tags; skip matching scenarios |

## Troubleshooting

If fixture generation fails at comparison, the working directory is preserved:

```bash
# LogMiner parsed output
cat tests/.work/<oracle_target>_<scenario>_XXXXXX/logminer.json

# OLR raw output
cat tests/.work/<oracle_target>_<scenario>_XXXXXX/olr_output.json

# OLR log (includes redo parsing details)
cat tests/.work/<oracle_target>_<scenario>_XXXXXX/olr_stdout.log

# Generated OLR config
cat tests/.work/<oracle_target>_<scenario>_XXXXXX/olr_config.json
```
