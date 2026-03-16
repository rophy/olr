-- compressed-table.sql: Test OLTP-compressed table.
-- Run as PDB user (e.g., olr_test/olr_test@//localhost:1521/FREEPDB1)
--
-- OLTP compression (ROW STORE COMPRESS ADVANCED) changes how Oracle
-- writes redo records. This tests whether OLR correctly captures DML
-- on compressed tables.
--
-- Note: Basic compression (ROW STORE COMPRESS BASIC) only compresses
-- during direct-path loads, not regular DML. OLTP compression compresses
-- during all DML operations.
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
    FROM user_tables WHERE table_name = 'TEST_COMPRESSED';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_COMPRESSED PURGE';
    END IF;
END;
/

CREATE TABLE TEST_COMPRESSED (
    id     NUMBER PRIMARY KEY,
    name   VARCHAR2(200),
    val    NUMBER,
    status VARCHAR2(20),
    data   VARCHAR2(500)
) ROW STORE COMPRESS ADVANCED;

ALTER TABLE TEST_COMPRESSED ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Record start SCN
DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- DML: INSERT rows with repetitive data (good compression candidates)
INSERT INTO TEST_COMPRESSED VALUES (1, 'Alice', 100, 'active', 'This is some data that might compress well');
INSERT INTO TEST_COMPRESSED VALUES (2, 'Bob', 200, 'active', 'This is some data that might compress well');
INSERT INTO TEST_COMPRESSED VALUES (3, 'Charlie', 300, 'active', 'This is some data that might compress well');
INSERT INTO TEST_COMPRESSED VALUES (4, 'Diana', 400, 'pending', 'Different data content here');
COMMIT;

-- DML: UPDATE
UPDATE TEST_COMPRESSED SET val = 150, status = 'updated' WHERE id = 1;
COMMIT;

UPDATE TEST_COMPRESSED SET name = 'Bob-Updated', data = 'Completely new data after update' WHERE id = 2;
COMMIT;

-- DML: DELETE
DELETE FROM TEST_COMPRESSED WHERE id = 3;
COMMIT;

-- DML: INSERT after delete
INSERT INTO TEST_COMPRESSED VALUES (5, 'Eve', 500, 'new', 'This is some data that might compress well');
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
