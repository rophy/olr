-- iot-table.sql: Test Index-Organized Table (IOT).
-- Run as PDB user (e.g., olr_test/olr_test@//localhost:1521/FREEPDB1)
--
-- IOTs store data in a B-tree index structure rather than a heap table.
-- The redo format differs from heap tables. This tests whether OLR
-- correctly captures DML on IOTs.
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
    FROM user_tables WHERE table_name = 'TEST_IOT';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_IOT PURGE';
    END IF;
END;
/

CREATE TABLE TEST_IOT (
    id     NUMBER,
    code   VARCHAR2(20),
    name   VARCHAR2(100),
    val    NUMBER,
    CONSTRAINT test_iot_pk PRIMARY KEY (id, code)
) ORGANIZATION INDEX;

ALTER TABLE TEST_IOT ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Record start SCN
DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- DML: INSERT
INSERT INTO TEST_IOT VALUES (1, 'A', 'Alice', 100);
INSERT INTO TEST_IOT VALUES (2, 'B', 'Bob', 200);
INSERT INTO TEST_IOT VALUES (3, 'A', 'Charlie', 300);
INSERT INTO TEST_IOT VALUES (1, 'B', 'Diana', 400);
COMMIT;

-- DML: UPDATE non-key columns
UPDATE TEST_IOT SET name = 'Alice-Updated', val = 150 WHERE id = 1 AND code = 'A';
COMMIT;

-- DML: DELETE
DELETE FROM TEST_IOT WHERE id = 2 AND code = 'B';
COMMIT;

-- DML: INSERT after delete (reuse key)
INSERT INTO TEST_IOT VALUES (2, 'B', 'Eve', 500);
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
