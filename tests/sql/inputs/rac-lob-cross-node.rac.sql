-- rac-lob-cross-node.rac.sql: LOB operations from both RAC nodes.
-- @TAG rac
-- Tests OLR's LOB handling (inline and out-of-row) when CLOB/BLOB writes
-- originate from different nodes. Verifies LOB split merging works correctly
-- when redo entries come from multiple threads.

-- @SETUP
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_RAC_LOB';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_RAC_LOB PURGE';
    END IF;
END;
/

CREATE TABLE TEST_RAC_LOB (
    id        NUMBER PRIMARY KEY,
    col_clob  CLOB,
    col_blob  BLOB,
    col_label VARCHAR2(50)
);

ALTER TABLE TEST_RAC_LOB ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- @NODE1
-- Small inline LOBs from node 1
INSERT INTO TEST_RAC_LOB VALUES (1, 'Short CLOB from N1', HEXTORAW('AABBCCDD'), 'n1-inline');
INSERT INTO TEST_RAC_LOB VALUES (2, NULL, NULL, 'n1-null-lobs');
COMMIT;

-- @NODE2
-- Small inline LOBs from node 2
INSERT INTO TEST_RAC_LOB VALUES (3, 'Short CLOB from N2', HEXTORAW('11223344'), 'n2-inline');
INSERT INTO TEST_RAC_LOB VALUES (4, NULL, NULL, 'n2-null-lobs');
COMMIT;

-- @NODE1
-- Medium out-of-row CLOB from node 1 (> 4000 bytes)
DECLARE
    v_clob CLOB;
BEGIN
    v_clob := RPAD('Medium CLOB from node 1. ', 8000, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ ');
    INSERT INTO TEST_RAC_LOB VALUES (5, v_clob, HEXTORAW(RPAD('FF', 200, 'EE')), 'n1-medium');
    COMMIT;
END;
/

-- @NODE2
-- Medium out-of-row CLOB from node 2
DECLARE
    v_clob CLOB;
BEGIN
    v_clob := RPAD('Medium CLOB from node 2. ', 8000, 'ZYXWVUTSRQPONMLKJIHGFEDCBA ');
    INSERT INTO TEST_RAC_LOB VALUES (6, v_clob, HEXTORAW(RPAD('AA', 200, 'BB')), 'n2-medium');
    COMMIT;
END;
/

-- @NODE1
-- Node 1 updates a LOB inserted by node 2
UPDATE TEST_RAC_LOB SET col_clob = 'N1 updated N2 row', col_label = 'n1-updated-n2' WHERE id = 3;
COMMIT;

-- @NODE2
-- Node 2 updates a LOB inserted by node 1
UPDATE TEST_RAC_LOB SET col_clob = 'N2 updated N1 row', col_blob = HEXTORAW('DEADBEEF'), col_label = 'n2-updated-n1' WHERE id = 1;
COMMIT;

-- @NODE1
-- Node 1 sets LOBs to NULL on a row from node 2
UPDATE TEST_RAC_LOB SET col_clob = NULL, col_blob = NULL, col_label = 'n1-nullified' WHERE id = 4;
COMMIT;

-- @NODE2
-- Node 2 sets NULL LOBs to values on a row from node 1
UPDATE TEST_RAC_LOB SET col_clob = 'Was null, now has value from N2', col_blob = HEXTORAW('CAFE'), col_label = 'n2-filled' WHERE id = 2;
COMMIT;

-- @NODE1
-- Node 1 deletes a row with LOBs from node 2
DELETE FROM TEST_RAC_LOB WHERE id = 6;
COMMIT;

-- @NODE2
-- Node 2 deletes a row with LOBs from node 1
DELETE FROM TEST_RAC_LOB WHERE id = 5;
COMMIT;
