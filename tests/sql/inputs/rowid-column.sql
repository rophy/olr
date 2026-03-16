-- rowid-column.sql: Test ROWID as a column data type.
-- Run as PDB user (e.g., olr_test/olr_test@//localhost:1521/FREEPDB1)
--
-- Tests OLR's handling of ROWID stored as an actual column value
-- (not the implicit ROWID pseudocolumn). ROWID columns store physical
-- row addresses as data.
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
    FROM user_tables WHERE table_name = 'TEST_ROWID_REF';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_ROWID_REF PURGE';
    END IF;

    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_ROWID_SRC';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_ROWID_SRC PURGE';
    END IF;
END;
/

-- Source table to get ROWIDs from
CREATE TABLE TEST_ROWID_SRC (
    id   NUMBER PRIMARY KEY,
    name VARCHAR2(100)
);

-- Table with ROWID column
CREATE TABLE TEST_ROWID_REF (
    id       NUMBER PRIMARY KEY,
    src_rid  ROWID,
    label    VARCHAR2(50)
);

ALTER TABLE TEST_ROWID_SRC ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE TEST_ROWID_REF ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Seed source rows to get ROWIDs
INSERT INTO TEST_ROWID_SRC VALUES (1, 'Alice');
INSERT INTO TEST_ROWID_SRC VALUES (2, 'Bob');
INSERT INTO TEST_ROWID_SRC VALUES (3, 'Charlie');
COMMIT;

-- Record start SCN
DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- DML: INSERT with ROWID values from source table
INSERT INTO TEST_ROWID_REF
SELECT 1, ROWID, 'ref-to-alice' FROM TEST_ROWID_SRC WHERE id = 1;
INSERT INTO TEST_ROWID_REF
SELECT 2, ROWID, 'ref-to-bob' FROM TEST_ROWID_SRC WHERE id = 2;
COMMIT;

-- DML: INSERT with NULL ROWID
INSERT INTO TEST_ROWID_REF VALUES (3, NULL, 'null-rowid');
COMMIT;

-- DML: UPDATE ROWID column to a different ROWID
UPDATE TEST_ROWID_REF SET
    src_rid = (SELECT ROWID FROM TEST_ROWID_SRC WHERE id = 3),
    label = 'ref-to-charlie'
WHERE id = 1;
COMMIT;

-- DML: UPDATE ROWID to NULL
UPDATE TEST_ROWID_REF SET src_rid = NULL, label = 'cleared' WHERE id = 2;
COMMIT;

-- DML: DELETE
DELETE FROM TEST_ROWID_REF WHERE id = 3;
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
