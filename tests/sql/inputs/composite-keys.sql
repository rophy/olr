-- composite-keys.sql: Test tables with multi-column primary keys.
-- Verifies that OLR correctly generates before-images with composite keys
-- and handles UPDATE/DELETE operations that identify rows by multiple columns.

SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET ECHO OFF

-- Setup: drop and recreate table
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_COMPOSITE_PK';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_COMPOSITE_PK PURGE';
    END IF;
END;
/

CREATE TABLE TEST_COMPOSITE_PK (
    region_id   NUMBER,
    product_id  NUMBER,
    sale_date   DATE,
    quantity    NUMBER,
    amount     NUMBER(12,2),
    notes      VARCHAR2(200),
    CONSTRAINT pk_composite PRIMARY KEY (region_id, product_id, sale_date)
);

ALTER TABLE TEST_COMPOSITE_PK ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Record start SCN
DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- DML: INSERT rows with composite keys
INSERT INTO TEST_COMPOSITE_PK VALUES (1, 100, TO_DATE('2025-01-15', 'YYYY-MM-DD'), 10, 99.99, 'first sale');
INSERT INTO TEST_COMPOSITE_PK VALUES (1, 200, TO_DATE('2025-01-15', 'YYYY-MM-DD'), 5, 49.50, 'second product');
INSERT INTO TEST_COMPOSITE_PK VALUES (2, 100, TO_DATE('2025-01-15', 'YYYY-MM-DD'), 20, 199.98, 'other region');
COMMIT;

-- DML: INSERT same product, different date
INSERT INTO TEST_COMPOSITE_PK VALUES (1, 100, TO_DATE('2025-02-01', 'YYYY-MM-DD'), 15, 149.85, 'feb sale');
COMMIT;

-- DML: UPDATE non-key columns
UPDATE TEST_COMPOSITE_PK SET quantity = 12, amount = 119.88, notes = 'adjusted'
WHERE region_id = 1 AND product_id = 100 AND sale_date = TO_DATE('2025-01-15', 'YYYY-MM-DD');
COMMIT;

-- DML: UPDATE that changes only one column
UPDATE TEST_COMPOSITE_PK SET notes = 'noted'
WHERE region_id = 2 AND product_id = 100 AND sale_date = TO_DATE('2025-01-15', 'YYYY-MM-DD');
COMMIT;

-- DML: DELETE by composite key
DELETE FROM TEST_COMPOSITE_PK
WHERE region_id = 1 AND product_id = 200 AND sale_date = TO_DATE('2025-01-15', 'YYYY-MM-DD');
COMMIT;

-- DML: DELETE another row
DELETE FROM TEST_COMPOSITE_PK
WHERE region_id = 1 AND product_id = 100 AND sale_date = TO_DATE('2025-02-01', 'YYYY-MM-DD');
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
