# Test Scenario Coverage Review

Last reviewed: 2026-03-16

## Current Coverage (53 scenarios)

### Single-Node (36 scenarios)

| Scenario | Area | Key Coverage |
|---|---|---|
| basic-crud | Core | INSERT, UPDATE, DELETE basics |
| data-types | Types | VARCHAR2, CHAR, NVARCHAR2, NUMBER, BINARY_FLOAT/DOUBLE, DATE, TIMESTAMP, RAW, INTEGER |
| number-precision | Types | NUMBER(38), sub-penny decimals, NaN, Infinity, zero, negative |
| timestamp-variants | Types | DATE, TIMESTAMP(0/3/6/9), midnight/epoch/end-of-day edge cases |
| timestamp-tz | Types | TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH LOCAL TIME ZONE, positive/negative/UTC offsets |
| interval-types | Types | INTERVAL YEAR TO MONTH, INTERVAL DAY TO SECOND, positive/negative/zero/large |
| lob-operations | Types | CLOB, BLOB — inline, out-of-row, NULL transitions |
| large-lobs | Types | Out-of-row LOBs (8KB-32KB CLOBs, 2KB BLOBs), UPDATE large CLOB |
| nchar-nclob | Types | NCHAR, NVARCHAR2, NCLOB — ASCII, Unicode (CJK/Korean/accented), NULL transitions |
| null-handling | Patterns | All-NULL inserts, NULL↔value transitions, NULL in before/after images |
| special-chars | Patterns | Quotes, newlines, tabs, backslash, Unicode in strings |
| wide-rows | Patterns | VARCHAR2(4000) max-length, block-spanning redo records |
| many-columns | Patterns | 60-column table stress test |
| large-transaction | Patterns | 200-row single commit, bulk UPDATE/DELETE |
| concurrent-updates | Patterns | Same row rapid updates across commits |
| interleaved-transactions | Patterns | Autonomous transactions creating genuine redo interleaving |
| long-spanning-txn | Patterns | Transaction spanning multiple archive logs |
| rollback | Patterns | ROLLBACK, SAVEPOINT + partial rollback |
| multi-table | Patterns | DML across 3 tables in mixed transactions |
| partitioned-table | Patterns | Range + list partitioned table DML |
| composite-keys | Patterns | Multi-column primary key (3 cols), UPDATE/DELETE by composite key |
| no-pk-table | Patterns | No primary key, ROWID-based identification, duplicate rows |
| empty-string-null | Patterns | Oracle '' = NULL semantics, NULL↔value transitions, single space |
| default-columns | Patterns | DEFAULT column values, INSERT with only PK, explicit NULL override |
| identity-columns | Patterns | GENERATED ALWAYS / BY DEFAULT AS IDENTITY, auto/explicit IDs |
| batch-dml | Patterns | INSERT ALL (multi-table), INSERT INTO..SELECT |
| merge-statement | Patterns | MERGE INTO with UPDATE/INSERT/DELETE clauses, multi-table source |
| subquery-dml | Patterns | UPDATE with scalar subquery, DELETE with EXISTS, UPDATE with IN subquery |
| virtual-columns | Patterns | GENERATED ALWAYS AS (expr) — virtual columns excluded from redo |
| ddl-add-column | DDL | ALTER TABLE ADD COLUMN mid-stream |
| ddl-operations | DDL | DROP COLUMN + ADD COLUMN in sequence |
| ddl-modify-rename | DDL | ALTER TABLE MODIFY (widen), RENAME COLUMN mid-stream |
| ddl-truncate | DDL | TRUNCATE TABLE — DML before/after truncate |
| compressed-table | Patterns | OLTP-compressed table (ROW STORE COMPRESS ADVANCED) — INSERT, UPDATE, DELETE |
| rowid-column | Types | ROWID as column type — INSERT, UPDATE, NULL transitions (OLR omits ROWID values, L8) |
| multibyte-passthrough | Charset | Big5 Chinese in US7ASCII DB (@TAG us7ascii) |

### RAC (17 scenarios)

| Scenario | Area | Key Coverage |
|---|---|---|
| rac-interleaved | Core | Basic alternating DML from both nodes |
| rac-alternating-commits | Core | Rapid single-row commits from alternating nodes |
| rac-concurrent-tables | Core | Each node operates on different table |
| rac-thread2-only | Core | All DML on node 2 only |
| rac-same-row-conflict | Ordering | Both nodes modify same rows, SCN ordering |
| rac-concurrent-open-txn | Txn | Overlapping uncommitted transactions across nodes |
| rac-rollback-cross-node | Txn | Rollback on one node while other commits |
| rac-large-interleaved | Scale | 200-row bulk on node 1, small txns on node 2 |
| rac-log-switch | Scale | Heavy DML spanning multiple redo log files |
| rac-long-txn-log-switch | Scale | 800-row open txn spanning log switches |
| rac-lob-cross-node | Types | LOB operations from both nodes |
| rac-large-lob | Types | Large out-of-row LOBs (8KB-32KB) from both nodes |
| rac-identity | Types | GENERATED ALWAYS AS IDENTITY from both nodes |
| rac-partitioned | Patterns | List-partitioned table DML from both nodes, cross-partition ops |
| rac-no-pk | Patterns | No-PK table across nodes, ROWID identification, duplicate rows |
| rac-ddl-cross-node | DDL | DDL on node 1, DML on node 2 |
| rac-multi-ddl | DDL | ALTER TABLE on multiple tables from different nodes |

## Remaining Gaps

### Table/Column Features

| Gap | Why It Matters | Priority | Status |
|---|---|---|---|
| Invisible columns | No OLR support (no property flag in SysCol) | Blocked | L11 — needs OLR code changes |
| Chained rows | Rows spanning multiple blocks (>block size) | Low | — |

### Blocked / Cannot Test

All limitations reference entries in [`KNOWN-LIMITATIONS.md`](KNOWN-LIMITATIONS.md).

| Gap | Why | Limitation |
|---|---|---|
| UROWID | LogMiner outputs "Unsupported Type" ([#11](https://github.com/rophy/olr/issues/11)) | L3 |
| ROWID column | OLR omits ROWID column values from output | L8 |
| BOOLEAN (Oracle 23ai) | LogMiner doesn't support BOOLEAN in SQL_REDO | L4 |
| JSON (native type) | Experimental in OLR (flag-gated) | — |
| XMLTYPE | Experimental in OLR (flag-gated) | — |
| LONG / LONG RAW | Legacy types — OLR type codes 8/24 not implemented | — |
| US7ASCII charset | OLR charset bug ([#2](https://github.com/rophy/olr/issues/2)) | L12 |
| Invisible columns | No property flag in SysCol | L11 |
| IOT | OLR doesn't discover IOTs in metadata | L9 |
| RAC LOB + log switch | OLR crash ([#14](https://github.com/rophy/olr/issues/14)) | L10 |

> **Note:** DDL scenarios (`@DDL` marker) are validated in redo-log regression tests (LogMiner comparison)
> but **not** in Debezium twin-test. The Debezium OLR adapter does not support mid-stream
> schema evolution (L7). Tracked in [rophy/olr#13](https://github.com/rophy/olr/issues/13).

## Notes

- TSTZ, TSLTZ, INTERVAL types: fixture generation shows WARN (LogMiner vs OLR format differs) but Debezium twin-tests pass (Debezium normalizes formats)
- DDL scenarios (@DDL marker) are skipped by Debezium twin-test by design (L7)
- LONG/LONG RAW are deprecated Oracle types (since 8i) — not worth implementing unless specific user demand
- Virtual columns are not stored in redo (computed on read) — OLR correctly excludes them from output
- OLTP-compressed tables work correctly — OLR handles compressed redo format
