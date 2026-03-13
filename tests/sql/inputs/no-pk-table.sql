-- no-pk-table.sql: Test table without a primary key.
-- Verifies that OLR handles tables with no PK, where ROWID is used
-- to identify rows in before-images.

SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET ECHO OFF

-- Setup: drop and recreate table
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_NO_PK';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_NO_PK PURGE';
    END IF;
END;
/

CREATE TABLE TEST_NO_PK (
    name    VARCHAR2(100),
    value   NUMBER,
    status  VARCHAR2(20)
);

ALTER TABLE TEST_NO_PK ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Record start SCN
DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- DML: INSERT rows (no unique identifier)
INSERT INTO TEST_NO_PK VALUES ('Alice', 100, 'active');
INSERT INTO TEST_NO_PK VALUES ('Bob', 200, 'active');
INSERT INTO TEST_NO_PK VALUES ('Alice', 300, 'pending');
COMMIT;

-- DML: UPDATE by value (affects one row)
UPDATE TEST_NO_PK SET value = 150, status = 'updated' WHERE name = 'Bob';
COMMIT;

-- DML: UPDATE that would match multiple rows — update only one with ROWNUM
UPDATE TEST_NO_PK SET status = 'modified' WHERE name = 'Alice' AND ROWNUM = 1;
COMMIT;

-- DML: DELETE one row
DELETE FROM TEST_NO_PK WHERE name = 'Bob';
COMMIT;

-- DML: INSERT duplicate values (exact same row data)
INSERT INTO TEST_NO_PK VALUES ('Charlie', 400, 'new');
INSERT INTO TEST_NO_PK VALUES ('Charlie', 400, 'new');
COMMIT;

-- DML: DELETE one of the duplicates
DELETE FROM TEST_NO_PK WHERE name = 'Charlie' AND ROWNUM = 1;
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
