-- rac-same-row-conflict.rac.sql: Both nodes modify the same rows.
-- @TAG rac
-- Tests OLR's SCN-ordered output when both nodes update/delete identical rows.
-- Wrong ordering here would mean data corruption in downstream consumers.

-- @SETUP
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_RAC_CONFLICT';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_RAC_CONFLICT PURGE';
    END IF;
END;
/

CREATE TABLE TEST_RAC_CONFLICT (
    id   NUMBER PRIMARY KEY,
    name VARCHAR2(100),
    val  NUMBER
);

ALTER TABLE TEST_RAC_CONFLICT ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- @NODE1
-- Insert initial rows from node 1
INSERT INTO TEST_RAC_CONFLICT VALUES (1, 'Alice', 100);
INSERT INTO TEST_RAC_CONFLICT VALUES (2, 'Bob', 200);
INSERT INTO TEST_RAC_CONFLICT VALUES (3, 'Charlie', 300);
COMMIT;

-- @NODE2
-- Node 2 updates a row inserted by node 1
UPDATE TEST_RAC_CONFLICT SET val = 201, name = 'Bob-N2' WHERE id = 2;
COMMIT;

-- @NODE1
-- Node 1 updates the same row again
UPDATE TEST_RAC_CONFLICT SET val = 202, name = 'Bob-N1' WHERE id = 2;
COMMIT;

-- @NODE2
-- Node 2 updates a different row
UPDATE TEST_RAC_CONFLICT SET val = 101, name = 'Alice-N2' WHERE id = 1;
COMMIT;

-- @NODE1
-- Node 1 deletes a row that node 2 previously updated
DELETE FROM TEST_RAC_CONFLICT WHERE id = 1;
COMMIT;

-- @NODE2
-- Node 2 deletes a row that both nodes updated
DELETE FROM TEST_RAC_CONFLICT WHERE id = 2;
COMMIT;
