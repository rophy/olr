-- batch-dml.sql: Test batch DML operations.
-- Verifies OLR handles INSERT ALL (multi-table insert) and
-- INSERT INTO ... SELECT patterns.

SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET ECHO OFF

-- Setup: drop and recreate tables
DECLARE
    v_table_exists NUMBER;
BEGIN
    FOR t IN (SELECT table_name FROM user_tables
              WHERE table_name IN ('TEST_BATCH_A', 'TEST_BATCH_B', 'TEST_BATCH_SOURCE')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' PURGE';
    END LOOP;
END;
/

CREATE TABLE TEST_BATCH_A (
    id     NUMBER PRIMARY KEY,
    name   VARCHAR2(50),
    value  NUMBER
);

CREATE TABLE TEST_BATCH_B (
    id     NUMBER PRIMARY KEY,
    name   VARCHAR2(50),
    value  NUMBER
);

CREATE TABLE TEST_BATCH_SOURCE (
    id     NUMBER PRIMARY KEY,
    name   VARCHAR2(50),
    value  NUMBER
);

ALTER TABLE TEST_BATCH_A ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE TEST_BATCH_B ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE TEST_BATCH_SOURCE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Record start SCN
DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- DML: INSERT ALL into multiple tables
INSERT ALL
    INTO TEST_BATCH_A (id, name, value) VALUES (1, 'batch-a-1', 100)
    INTO TEST_BATCH_A (id, name, value) VALUES (2, 'batch-a-2', 200)
    INTO TEST_BATCH_B (id, name, value) VALUES (1, 'batch-b-1', 300)
    INTO TEST_BATCH_B (id, name, value) VALUES (2, 'batch-b-2', 400)
SELECT 1 FROM DUAL;
COMMIT;

-- DML: Populate source for INSERT..SELECT
INSERT INTO TEST_BATCH_SOURCE VALUES (10, 'source-1', 1000);
INSERT INTO TEST_BATCH_SOURCE VALUES (20, 'source-2', 2000);
INSERT INTO TEST_BATCH_SOURCE VALUES (30, 'source-3', 3000);
COMMIT;

-- DML: INSERT INTO ... SELECT
INSERT INTO TEST_BATCH_A (id, name, value)
    SELECT id, name, value FROM TEST_BATCH_SOURCE WHERE id <= 20;
COMMIT;

-- DML: UPDATE multiple rows
UPDATE TEST_BATCH_A SET value = value + 1 WHERE id <= 2;
COMMIT;

-- DML: DELETE multiple rows
DELETE FROM TEST_BATCH_B WHERE id <= 2;
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
