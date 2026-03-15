-- virtual-columns.sql: Test virtual (computed) columns.
-- Run as PDB user (e.g., olr_test/olr_test@//localhost:1521/FREEPDB1)
--
-- Virtual columns (GENERATED ALWAYS AS) are computed on read, not stored
-- in redo logs. OLR should exclude them from before/after images.
-- This test validates that DML on tables with virtual columns works
-- correctly and virtual column values are not included in output.
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
    FROM user_tables WHERE table_name = 'TEST_VIRTUAL';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_VIRTUAL PURGE';
    END IF;
END;
/

CREATE TABLE TEST_VIRTUAL (
    id         NUMBER PRIMARY KEY,
    quantity   NUMBER,
    unit_price NUMBER(10,2),
    total_cost NUMBER GENERATED ALWAYS AS (quantity * unit_price) VIRTUAL,
    first_name VARCHAR2(50),
    last_name  VARCHAR2(50),
    full_name  VARCHAR2(101) GENERATED ALWAYS AS (first_name || ' ' || last_name) VIRTUAL
);

ALTER TABLE TEST_VIRTUAL ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Record start SCN
DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- DML: INSERT (virtual columns auto-computed)
INSERT INTO TEST_VIRTUAL (id, quantity, unit_price, first_name, last_name)
VALUES (1, 10, 25.50, 'John', 'Doe');
INSERT INTO TEST_VIRTUAL (id, quantity, unit_price, first_name, last_name)
VALUES (2, 5, 100.00, 'Jane', 'Smith');
INSERT INTO TEST_VIRTUAL (id, quantity, unit_price, first_name, last_name)
VALUES (3, 1, 999.99, 'Alice', 'Johnson');
COMMIT;

-- DML: UPDATE source columns (virtual columns recalculate)
UPDATE TEST_VIRTUAL SET quantity = 20, unit_price = 30.00 WHERE id = 1;
COMMIT;

UPDATE TEST_VIRTUAL SET first_name = 'Robert', last_name = 'Williams' WHERE id = 2;
COMMIT;

-- DML: UPDATE with NULL (virtual column becomes NULL)
UPDATE TEST_VIRTUAL SET quantity = NULL WHERE id = 3;
COMMIT;

-- DML: DELETE
DELETE FROM TEST_VIRTUAL WHERE id = 3;
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
