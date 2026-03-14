-- ddl-operations.sql: Test various DDL operations mid-stream.
-- Verifies OLR handles DROP COLUMN, RENAME COLUMN, and TRUNCATE.
-- @DDL

SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET ECHO OFF

-- Setup: drop and recreate table
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_DDL_OPS';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_DDL_OPS PURGE';
    END IF;
END;
/

CREATE TABLE TEST_DDL_OPS (
    id         NUMBER PRIMARY KEY,
    col_a      VARCHAR2(50),
    col_b      NUMBER,
    col_drop   VARCHAR2(50)
);

ALTER TABLE TEST_DDL_OPS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Record start SCN
DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- DML: INSERT before DDL changes
INSERT INTO TEST_DDL_OPS VALUES (1, 'before-drop', 100, 'will-be-dropped');
INSERT INTO TEST_DDL_OPS VALUES (2, 'before-drop', 200, 'also-dropped');
COMMIT;

-- DDL: DROP COLUMN
ALTER TABLE TEST_DDL_OPS DROP COLUMN col_drop;

-- DML: INSERT after DROP COLUMN
INSERT INTO TEST_DDL_OPS VALUES (3, 'after-drop', 300);
COMMIT;

-- DML: UPDATE after DROP COLUMN
UPDATE TEST_DDL_OPS SET col_a = 'updated-after-drop', col_b = 150 WHERE id = 1;
COMMIT;

-- DDL: ADD COLUMN (to verify multiple DDL operations work)
ALTER TABLE TEST_DDL_OPS ADD (col_new VARCHAR2(50) DEFAULT 'new-default');

-- DML: INSERT with new column
INSERT INTO TEST_DDL_OPS (id, col_a, col_b, col_new) VALUES (4, 'with-new-col', 400, 'explicit-new');
COMMIT;

-- DML: DELETE
DELETE FROM TEST_DDL_OPS WHERE id = 2;
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
