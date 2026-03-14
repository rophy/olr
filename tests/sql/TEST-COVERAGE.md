# Test Scenario Coverage Review

Last reviewed: 2026-03-14

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

## Remaining Gaps

| Gap | Why | Status |
|---|---|---|
| UROWID | LogMiner outputs "Unsupported Type" — cannot validate ([#11](https://github.com/rophy/olr/issues/11)) | Skipped |
| BOOLEAN (Oracle 23ai) | New type — LogMiner doesn't support BOOLEAN in SQL_REDO | Blocked |
| JSON (native type) | Experimental in OLR (flag-gated) | Not priority |
| XMLTYPE | Experimental in OLR (flag-gated) | Not priority |

## Notes

- TSTZ, TSLTZ, INTERVAL types: fixture generation shows WARN (LogMiner vs OLR format differs) but Debezium twin-tests pass (Debezium normalizes formats)
- DDL scenarios (@DDL marker) are skipped by Debezium twin-test by design
