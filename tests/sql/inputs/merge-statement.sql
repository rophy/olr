-- merge-statement.sql: Test MERGE INTO statement.
-- Run as PDB user (e.g., olr_test/olr_test@//localhost:1521/FREEPDB1)
--
-- MERGE generates standard INSERT/UPDATE/DELETE redo records (not a special
-- opcode), but it's important to verify that OLR correctly captures all DML
-- produced by a single MERGE statement.
--
-- Outputs: FIXTURE_SCN_START: <scn> and FIXTURE_SCN_END: <scn>

SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET ECHO OFF

-- Setup: drop and recreate tables
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_MERGE_TARGET';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_MERGE_TARGET PURGE';
    END IF;

    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_MERGE_SOURCE';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_MERGE_SOURCE PURGE';
    END IF;
END;
/

CREATE TABLE TEST_MERGE_TARGET (
    id     NUMBER PRIMARY KEY,
    name   VARCHAR2(100),
    val    NUMBER,
    status VARCHAR2(20)
);

CREATE TABLE TEST_MERGE_SOURCE (
    id     NUMBER PRIMARY KEY,
    name   VARCHAR2(100),
    val    NUMBER,
    status VARCHAR2(20)
);

ALTER TABLE TEST_MERGE_TARGET ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Record start SCN
DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- Seed target with initial data
INSERT INTO TEST_MERGE_TARGET VALUES (1, 'Alice', 100, 'active');
INSERT INTO TEST_MERGE_TARGET VALUES (2, 'Bob', 200, 'active');
INSERT INTO TEST_MERGE_TARGET VALUES (3, 'Charlie', 300, 'active');
COMMIT;

-- Seed source with merge data
-- id=1: exists in target → UPDATE
-- id=2: exists in target → UPDATE
-- id=4: not in target → INSERT
-- id=5: not in target → INSERT
INSERT INTO TEST_MERGE_SOURCE VALUES (1, 'Alice-Updated', 150, 'modified');
INSERT INTO TEST_MERGE_SOURCE VALUES (2, 'Bob-Updated', 250, 'modified');
INSERT INTO TEST_MERGE_SOURCE VALUES (4, 'Diana', 400, 'new');
INSERT INTO TEST_MERGE_SOURCE VALUES (5, 'Eve', 500, 'new');
COMMIT;

-- MERGE: UPDATE matching rows + INSERT non-matching rows
MERGE INTO TEST_MERGE_TARGET t
USING TEST_MERGE_SOURCE s
ON (t.id = s.id)
WHEN MATCHED THEN
    UPDATE SET t.name = s.name, t.val = s.val, t.status = s.status
WHEN NOT MATCHED THEN
    INSERT (id, name, val, status) VALUES (s.id, s.name, s.val, s.status);
COMMIT;

-- Prepare source for MERGE with DELETE clause
-- Only id=1 in source → only id=1 matches ON (t.id = s.id)
-- id=1: matched → UPDATE to 'final', then DELETE WHERE status = 'final'
-- id=3: not matched (not in source) → untouched
DELETE FROM TEST_MERGE_SOURCE;
INSERT INTO TEST_MERGE_SOURCE VALUES (1, 'Alice-Final', 175, 'final');
COMMIT;

-- MERGE with DELETE clause: UPDATE matched + DELETE where condition met
MERGE INTO TEST_MERGE_TARGET t
USING TEST_MERGE_SOURCE s
ON (t.id = s.id)
WHEN MATCHED THEN
    UPDATE SET t.name = s.name, t.val = s.val, t.status = s.status
    DELETE WHERE t.status = 'final';
COMMIT;

-- Record end SCN
DECLARE
    v_end_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_end_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_END: ' || v_end_scn);
END;
/

EXIT
