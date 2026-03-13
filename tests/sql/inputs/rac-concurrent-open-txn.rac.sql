-- rac-concurrent-open-txn.rac.sql: Overlapping open transactions on both nodes.
-- @TAG rac
-- Tests OLR's handling when both nodes have uncommitted transactions that modify
-- the same rows. Unlike rac-same-row-conflict which commits between each node's
-- work, this scenario keeps transactions open across node blocks to test
-- OLR's transaction tracking with concurrent pending transactions.

-- @SETUP
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_RAC_CONCURRENT_TXN';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_RAC_CONCURRENT_TXN PURGE';
    END IF;
END;
/

CREATE TABLE TEST_RAC_CONCURRENT_TXN (
    id   NUMBER PRIMARY KEY,
    name VARCHAR2(100),
    val  NUMBER
);

ALTER TABLE TEST_RAC_CONCURRENT_TXN ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Seed rows so both nodes can modify existing data
INSERT INTO TEST_RAC_CONCURRENT_TXN VALUES (1, 'seed-A', 100);
INSERT INTO TEST_RAC_CONCURRENT_TXN VALUES (2, 'seed-B', 200);
INSERT INTO TEST_RAC_CONCURRENT_TXN VALUES (3, 'seed-C', 300);
INSERT INTO TEST_RAC_CONCURRENT_TXN VALUES (4, 'seed-D', 400);
COMMIT;

DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- @NODE1
-- Node 1 starts a transaction but does NOT commit yet
INSERT INTO TEST_RAC_CONCURRENT_TXN VALUES (10, 'n1-pending-1', 1000);
INSERT INTO TEST_RAC_CONCURRENT_TXN VALUES (11, 'n1-pending-2', 1100);
UPDATE TEST_RAC_CONCURRENT_TXN SET val = 101, name = 'n1-updated-A' WHERE id = 1;

-- @NODE2
-- Node 2 starts its own transaction (node 1's txn is still open)
INSERT INTO TEST_RAC_CONCURRENT_TXN VALUES (20, 'n2-pending-1', 2000);
UPDATE TEST_RAC_CONCURRENT_TXN SET val = 201, name = 'n2-updated-B' WHERE id = 2;
-- Node 2 commits first
COMMIT;

-- @NODE1
-- Node 1 does more work in its still-open transaction, then commits
INSERT INTO TEST_RAC_CONCURRENT_TXN VALUES (12, 'n1-pending-3', 1200);
COMMIT;

-- @NODE2
-- Node 2 opens another transaction
INSERT INTO TEST_RAC_CONCURRENT_TXN VALUES (21, 'n2-second-txn', 2100);
UPDATE TEST_RAC_CONCURRENT_TXN SET val = 301, name = 'n2-updated-C' WHERE id = 3;

-- @NODE1
-- Node 1 opens a new transaction while node 2's is still open
INSERT INTO TEST_RAC_CONCURRENT_TXN VALUES (13, 'n1-second-txn', 1300);
UPDATE TEST_RAC_CONCURRENT_TXN SET val = 401, name = 'n1-updated-D' WHERE id = 4;
COMMIT;

-- @NODE2
-- Node 2 finally commits
COMMIT;

-- @NODE1
-- Final cleanup: node 1 deletes some rows
DELETE FROM TEST_RAC_CONCURRENT_TXN WHERE id = 20;
COMMIT;

-- @NODE2
-- Node 2 deletes a row from node 1
DELETE FROM TEST_RAC_CONCURRENT_TXN WHERE id = 10;
COMMIT;
