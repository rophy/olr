-- ddl-truncate.sql: Test TRUNCATE TABLE.
-- @DDL
-- Run as PDB user (e.g., olr_test/olr_test@//localhost:1521/FREEPDB1)
--
-- Tests that OLR captures DML before and after TRUNCATE TABLE.
-- TRUNCATE is DDL (not DML) — it doesn't generate per-row redo records,
-- but subsequent DML should continue to be captured correctly.
--
-- Outputs: FIXTURE_SCN_START: <scn> and FIXTURE_SCN_END: <scn>

SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET ECHO OFF

-- Setup: drop and recreate table
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_TRUNCATE';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_TRUNCATE PURGE';
    END IF;
END;
/

CREATE TABLE TEST_TRUNCATE (
    id     NUMBER PRIMARY KEY,
    name   VARCHAR2(100),
    val    NUMBER
);

ALTER TABLE TEST_TRUNCATE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Record start SCN
DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- Phase 1: DML before truncate
INSERT INTO TEST_TRUNCATE VALUES (1, 'Alice', 100);
INSERT INTO TEST_TRUNCATE VALUES (2, 'Bob', 200);
INSERT INTO TEST_TRUNCATE VALUES (3, 'Charlie', 300);
COMMIT;

UPDATE TEST_TRUNCATE SET val = 150 WHERE id = 1;
COMMIT;

-- DDL: TRUNCATE (removes all rows without per-row redo)
TRUNCATE TABLE TEST_TRUNCATE;

-- Phase 2: DML after truncate (reusing IDs is valid since table was truncated)
INSERT INTO TEST_TRUNCATE VALUES (1, 'Diana', 400);
INSERT INTO TEST_TRUNCATE VALUES (2, 'Eve', 500);
COMMIT;

UPDATE TEST_TRUNCATE SET name = 'Diana-Updated' WHERE id = 1;
COMMIT;

DELETE FROM TEST_TRUNCATE WHERE id = 2;
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
