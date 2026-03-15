# Test Scenario Coverage Review

Last reviewed: 2026-03-15

## Current Coverage (43 scenarios)

### Single-Node (28 scenarios)

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
| ddl-add-column | DDL | ALTER TABLE ADD COLUMN mid-stream |
| ddl-operations | DDL | DROP COLUMN + ADD COLUMN in sequence |
| multibyte-passthrough | Charset | Big5 Chinese in US7ASCII DB (@TAG us7ascii) |

### RAC (15 scenarios)

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
| rac-ddl-cross-node | DDL | DDL on node 1, DML on node 2 |
| rac-multi-ddl | DDL | ALTER TABLE on multiple tables from different nodes |

## Identified Gaps

### Data Types Not Tested (supported by both OLR + LogMiner)

| Gap | OLR Support | LogMiner Support | Priority | Proposed Scenario |
|---|---|---|---|---|
| NCHAR | Yes (parseString) | Yes | High | `nchar-nclob` |
| NCLOB | Yes (parseLob) | Yes | High | `nchar-nclob` |
| ROWID (as column type) | Yes | Yes | Medium | `rowid-column` |

### DDL Operations Not Tested

| Gap | Priority | Proposed Scenario |
|---|---|---|
| ALTER TABLE MODIFY COLUMN (type/size change) | High | `ddl-modify-rename` |
| ALTER TABLE RENAME COLUMN | High | `ddl-modify-rename` |
| TRUNCATE TABLE | High | `ddl-truncate` |

> **Note:** DDL scenarios are validated in redo-log regression tests (LogMiner comparison)
> but **not** in Debezium twin-test. The Debezium OLR adapter does not support mid-stream
> schema evolution — it uses the initial snapshot schema and cannot handle ALTER TABLE
> during streaming. The LogMiner adapter handles this via JDBC dictionary refresh, but
> the OLR adapter lacks this feature. Tracked in [rophy/olr#13](https://github.com/rophy/olr/issues/13).

### DML Patterns Not Tested

| Gap | Why It Matters | Priority | Proposed Scenario |
|---|---|---|---|
| MERGE statement | Common DML, distinct redo pattern | High | `merge-statement` |
| UPDATE with subquery | `UPDATE t SET x = (SELECT ...)` | Medium | `subquery-dml` |
| INSERT with RETURNING | May generate different redo | Low | — |

### Table/Column Features Not Tested

| Gap | Why It Matters | Priority | Proposed Scenario |
|---|---|---|---|
| Virtual columns | GENERATED ALWAYS AS (expr) — not identity | High | `virtual-invisible-columns` |
| Invisible columns | ALTER TABLE ... INVISIBLE | High | `virtual-invisible-columns` |
| Index-Organized Table (IOT) | Different physical storage, different redo format | Medium | `iot-table` |
| Compressed table (OLTP) | Compression changes redo format | Medium | `compressed-table` |
| Chained rows | Rows spanning multiple blocks (>block size) | Low | — |

### RAC Combination Gaps

| Gap | Why It Matters | Priority | Proposed Scenario |
|---|---|---|---|
| RAC + partitioned table | DML to same partitioned table from both nodes | High | `rac-partitioned.rac.sql` |
| RAC + no-PK table | ROWID-based identification across threads | High | `rac-no-pk.rac.sql` |
| RAC + large LOB (>8KB) | Out-of-row LOB assembly across threads | Medium | `rac-large-lob.rac.sql` |
| RAC + identity columns | Sequence-based identity from both nodes | Medium | `rac-identity.rac.sql` |
| RAC + LOB spanning log switch | LOB cross-node + log file boundary | Medium | `rac-lob-log-switch.rac.sql` |

### Blocked / Cannot Test

| Gap | Why | Status |
|---|---|---|
| UROWID | LogMiner outputs "Unsupported Type" — cannot validate ([#11](https://github.com/rophy/olr/issues/11)) | Blocked (LogMiner) |
| BOOLEAN (Oracle 23ai) | LogMiner doesn't support BOOLEAN in SQL_REDO | Blocked (LogMiner) |
| JSON (native type) | Experimental in OLR (flag-gated) | Blocked (OLR) |
| XMLTYPE | Experimental in OLR (flag-gated) | Blocked (OLR) |
| LONG / LONG RAW | Legacy types — OLR type codes 8/24 not implemented | Not planned |
| US7ASCII charset | OLR charset bug ([#2](https://github.com/rophy/olr/issues/2)) | Blocked (OLR) |

## Implementation Priority

**Phase 1 — High priority (common real-world patterns):**
1. `nchar-nclob` — NCHAR, NVARCHAR2, NCLOB types
2. `ddl-modify-rename` — ALTER TABLE MODIFY/RENAME COLUMN (@DDL)
3. `merge-statement` — MERGE INTO ... USING ...
4. `virtual-invisible-columns` — Virtual + invisible column handling
5. `rac-partitioned.rac.sql` — Partitioned table DML from both nodes
6. `rac-no-pk.rac.sql` — No-PK table across RAC nodes

**Phase 2 — Medium priority (less common but important):**
7. `ddl-truncate` — TRUNCATE TABLE (@DDL)
8. `iot-table` — Index-Organized Table
9. `compressed-table` — OLTP-compressed table
10. `rac-large-lob.rac.sql` — Large out-of-row LOB from both nodes
11. `rac-identity.rac.sql` — Identity columns across nodes
12. `rowid-column` — ROWID as a column data type
13. `subquery-dml` — UPDATE/DELETE with correlated subqueries

## Notes

- TSTZ, TSLTZ, INTERVAL types: fixture generation shows WARN (LogMiner vs OLR format differs) but Debezium twin-tests pass (Debezium normalizes formats)
- DDL scenarios (@DDL marker) are skipped by Debezium twin-test by design
- LONG/LONG RAW are deprecated Oracle types (since 8i) — not worth implementing unless specific user demand
- IOT and compressed table redo formats are significantly different from heap tables — may require OLR code changes, not just new test scenarios
- Virtual columns are not stored in redo (computed on read) — OLR should exclude them; test validates this behavior
