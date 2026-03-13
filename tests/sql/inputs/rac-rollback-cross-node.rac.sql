-- rac-rollback-cross-node.rac.sql: Rollback on one node while the other commits.
-- @TAG rac
-- Tests that OLR correctly discards rolled-back transactions from one thread
-- while emitting committed transactions from the other.

-- @SETUP
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_RAC_ROLLBACK';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_RAC_ROLLBACK PURGE';
    END IF;
END;
/

CREATE TABLE TEST_RAC_ROLLBACK (
    id   NUMBER PRIMARY KEY,
    name VARCHAR2(100),
    val  NUMBER
);

ALTER TABLE TEST_RAC_ROLLBACK ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- @NODE1
-- Node 1: insert and rollback (should NOT appear in output)
INSERT INTO TEST_RAC_ROLLBACK VALUES (1, 'Ghost-A', 100);
INSERT INTO TEST_RAC_ROLLBACK VALUES (2, 'Ghost-B', 200);
INSERT INTO TEST_RAC_ROLLBACK VALUES (3, 'Ghost-C', 300);
ROLLBACK;

-- @NODE2
-- Node 2: insert and commit (SHOULD appear in output)
INSERT INTO TEST_RAC_ROLLBACK VALUES (10, 'Real-X', 1000);
INSERT INTO TEST_RAC_ROLLBACK VALUES (11, 'Real-Y', 1100);
COMMIT;

-- @NODE1
-- Node 1: insert and commit after the rollback (SHOULD appear)
INSERT INTO TEST_RAC_ROLLBACK VALUES (20, 'Real-Z', 2000);
COMMIT;

-- @NODE2
-- Node 2: update and rollback (should NOT appear)
UPDATE TEST_RAC_ROLLBACK SET val = 9999 WHERE id = 10;
ROLLBACK;

-- @NODE1
-- Node 1: update and commit (SHOULD appear)
UPDATE TEST_RAC_ROLLBACK SET val = 2001, name = 'Real-Z-Updated' WHERE id = 20;
COMMIT;

-- @NODE2
-- Node 2: delete and commit (SHOULD appear)
DELETE FROM TEST_RAC_ROLLBACK WHERE id = 11;
COMMIT;
