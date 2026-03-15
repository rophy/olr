-- rac-large-lob.rac.sql: Large out-of-row LOBs from both RAC nodes.
-- @TAG rac
-- Tests OLR's out-of-row LOB assembly when large LOBs (>8KB) originate
-- from different RAC nodes. Verifies LOB chunk reassembly works correctly
-- across redo threads.

-- @SETUP
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_RAC_LARGELOB';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_RAC_LARGELOB PURGE';
    END IF;
END;
/

CREATE TABLE TEST_RAC_LARGELOB (
    id        NUMBER PRIMARY KEY,
    col_clob  CLOB,
    col_label VARCHAR2(50)
);

ALTER TABLE TEST_RAC_LARGELOB ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- @NODE1
-- Large CLOB from node 1 (~8KB)
DECLARE
    v_clob CLOB;
BEGIN
    v_clob := RPAD('Large CLOB from node 1. ', 8000, 'NODE1-DATA-ABCDEFGHIJKLMNOP ');
    INSERT INTO TEST_RAC_LARGELOB VALUES (1, v_clob, 'n1-8k');
    COMMIT;
END;
/

-- @NODE2
-- Large CLOB from node 2 (~8KB)
DECLARE
    v_clob CLOB;
BEGIN
    v_clob := RPAD('Large CLOB from node 2. ', 8000, 'NODE2-DATA-ZYXWVUTSRQPONMLK ');
    INSERT INTO TEST_RAC_LARGELOB VALUES (2, v_clob, 'n2-8k');
    COMMIT;
END;
/

-- @NODE1
-- Very large CLOB from node 1 (~32KB)
DECLARE
    v_clob CLOB;
BEGIN
    v_clob := RPAD('Very large CLOB from node 1. ', 32000, 'N1-VERYLARGE-REPEAT ');
    INSERT INTO TEST_RAC_LARGELOB VALUES (3, v_clob, 'n1-32k');
    COMMIT;
END;
/

-- @NODE2
-- Update the large CLOB from node 1 with new data from node 2
DECLARE
    v_clob CLOB;
BEGIN
    v_clob := RPAD('Updated by node 2. ', 8000, 'N2-UPDATED-CONTENT ');
    UPDATE TEST_RAC_LARGELOB SET col_clob = v_clob, col_label = 'n2-updated-n1' WHERE id = 1;
    COMMIT;
END;
/

-- @NODE1
-- Small inline update on the large LOB row from node 2
UPDATE TEST_RAC_LARGELOB SET col_clob = 'Now small from N1', col_label = 'n1-shrunk-n2' WHERE id = 2;
COMMIT;

-- @NODE2
-- Delete a large LOB row
DELETE FROM TEST_RAC_LARGELOB WHERE id = 3;
COMMIT;
