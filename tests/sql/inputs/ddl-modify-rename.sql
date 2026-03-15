-- ddl-modify-rename.sql: Test ALTER TABLE MODIFY and RENAME COLUMN.
-- @DDL
-- Run as PDB user (e.g., olr_test/olr_test@//localhost:1521/FREEPDB1)
--
-- Tests OLR's ability to track schema changes from MODIFY COLUMN
-- (type/size changes) and RENAME COLUMN mid-stream.
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
    FROM user_tables WHERE table_name = 'TEST_DDL_MOD';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_DDL_MOD PURGE';
    END IF;
END;
/

CREATE TABLE TEST_DDL_MOD (
    id     NUMBER PRIMARY KEY,
    name   VARCHAR2(50),
    val    NUMBER(5),
    status VARCHAR2(10)
);

ALTER TABLE TEST_DDL_MOD ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Record start SCN
DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- Phase 1: DML with original schema
INSERT INTO TEST_DDL_MOD VALUES (1, 'Alice', 100, 'active');
INSERT INTO TEST_DDL_MOD VALUES (2, 'Bob', 200, 'pending');
COMMIT;

-- DDL: MODIFY COLUMN — widen VARCHAR2 and change NUMBER precision
ALTER TABLE TEST_DDL_MOD MODIFY (name VARCHAR2(200));
ALTER TABLE TEST_DDL_MOD MODIFY (val NUMBER(10,2));

-- Phase 2: DML with modified schema
INSERT INTO TEST_DDL_MOD VALUES (3, 'A much longer name that exceeds the original 50 char limit', 12345.67, 'active');
COMMIT;

UPDATE TEST_DDL_MOD SET name = 'Updated Alice with longer name', val = 999.99 WHERE id = 1;
COMMIT;

-- DDL: RENAME COLUMN
ALTER TABLE TEST_DDL_MOD RENAME COLUMN status TO state;

-- Phase 3: DML with renamed column
INSERT INTO TEST_DDL_MOD VALUES (4, 'Diana', 400, 'new');
COMMIT;

UPDATE TEST_DDL_MOD SET state = 'done' WHERE id = 2;
COMMIT;

DELETE FROM TEST_DDL_MOD WHERE id = 1;
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
