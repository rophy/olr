-- rac-long-txn-log-switch.rac.sql: Single long transaction spanning log switches.
-- @TAG rac
-- Tests OLR's ability to handle a single open transaction whose redo spans
-- multiple log files, while the other node interleaves short transactions.
-- Unlike rac-log-switch which uses separate transactions per phase, this
-- scenario keeps one transaction open across the entire bulk operation.

-- @SETUP
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_RAC_LONG_TXN';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_RAC_LONG_TXN PURGE';
    END IF;
END;
/

CREATE TABLE TEST_RAC_LONG_TXN (
    id    NUMBER PRIMARY KEY,
    phase VARCHAR2(200),
    val   NUMBER
);

ALTER TABLE TEST_RAC_LONG_TXN ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- @NODE1
-- Node 1: begin a SINGLE long transaction with bulk inserts
-- This should generate enough redo to span multiple log files
-- The transaction stays open until the final COMMIT
BEGIN
    FOR i IN 1..500 LOOP
        INSERT INTO TEST_RAC_LONG_TXN VALUES (i, 'long-txn-n1-' || LPAD(TO_CHAR(i), 10, 'X'), i * 10);
    END LOOP;
    -- NO COMMIT here — transaction stays open
END;
/

-- @NODE2
-- Node 2: short committed transactions while node 1's long txn is open
INSERT INTO TEST_RAC_LONG_TXN VALUES (10001, 'short-n2-a', 1);
COMMIT;

INSERT INTO TEST_RAC_LONG_TXN VALUES (10002, 'short-n2-b', 2);
INSERT INTO TEST_RAC_LONG_TXN VALUES (10003, 'short-n2-c', 3);
COMMIT;

-- @NODE1
-- Node 1: more work in the same open transaction
BEGIN
    FOR i IN 501..700 LOOP
        INSERT INTO TEST_RAC_LONG_TXN VALUES (i, 'long-txn-n1-' || LPAD(TO_CHAR(i), 10, 'X'), i * 10);
    END LOOP;
    -- Still no commit
END;
/

-- @NODE2
-- Node 2: another short transaction
INSERT INTO TEST_RAC_LONG_TXN VALUES (10004, 'short-n2-d', 4);
UPDATE TEST_RAC_LONG_TXN SET val = 11, phase = 'updated-n2' WHERE id = 10001;
COMMIT;

-- @NODE1
-- Node 1: final batch and COMMIT the long transaction
BEGIN
    FOR i IN 701..800 LOOP
        INSERT INTO TEST_RAC_LONG_TXN VALUES (i, 'long-txn-n1-' || LPAD(TO_CHAR(i), 10, 'X'), i * 10);
    END LOOP;
    COMMIT;
END;
/

-- @NODE2
-- Node 2: final short transaction after node 1's long txn commits
DELETE FROM TEST_RAC_LONG_TXN WHERE id = 10002;
INSERT INTO TEST_RAC_LONG_TXN VALUES (10005, 'short-n2-e', 5);
COMMIT;
