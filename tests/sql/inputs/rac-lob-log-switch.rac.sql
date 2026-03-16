-- rac-lob-log-switch.rac.sql: LOB operations spanning log switches on RAC.
-- @TAG rac
-- Tests OLR's LOB assembly when LOB operations from both nodes span
-- multiple redo log files. Generates enough redo volume to naturally
-- trigger log switches on both nodes.

-- @SETUP
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_RAC_LOB_LS';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_RAC_LOB_LS PURGE';
    END IF;
END;
/

CREATE TABLE TEST_RAC_LOB_LS (
    id        NUMBER PRIMARY KEY,
    col_clob  CLOB,
    col_label VARCHAR2(50)
);

ALTER TABLE TEST_RAC_LOB_LS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- @NODE1
-- Bulk LOB inserts from node 1 to generate redo volume
DECLARE
    v_clob CLOB;
BEGIN
    FOR i IN 1..20 LOOP
        v_clob := RPAD('N1-LOB-' || i || ' ', 4000, 'ABCDEFGHIJKLMNOP ');
        INSERT INTO TEST_RAC_LOB_LS VALUES (i, v_clob, 'n1-batch-' || i);
        COMMIT;
    END LOOP;
END;
/

-- @NODE2
-- Bulk LOB inserts from node 2 to generate redo volume
DECLARE
    v_clob CLOB;
BEGIN
    FOR i IN 101..120 LOOP
        v_clob := RPAD('N2-LOB-' || i || ' ', 4000, 'ZYXWVUTSRQPONMLK ');
        INSERT INTO TEST_RAC_LOB_LS VALUES (i, v_clob, 'n2-batch-' || i);
        COMMIT;
    END LOOP;
END;
/

-- @NODE1
-- Update some LOBs from node 1
DECLARE
    v_clob CLOB;
BEGIN
    FOR i IN 1..5 LOOP
        v_clob := RPAD('N1-UPDATED-' || i || ' ', 4000, 'UPDATED-DATA ');
        UPDATE TEST_RAC_LOB_LS SET col_clob = v_clob, col_label = 'n1-updated-' || i WHERE id = i;
        COMMIT;
    END LOOP;
END;
/

-- @NODE2
-- Update some LOBs from node 2 (cross-node: updating rows from node 1)
DECLARE
    v_clob CLOB;
BEGIN
    FOR i IN 6..10 LOOP
        v_clob := RPAD('N2-CROSS-UPDATE-' || i || ' ', 4000, 'CROSS-NODE ');
        UPDATE TEST_RAC_LOB_LS SET col_clob = v_clob, col_label = 'n2-cross-' || i WHERE id = i;
        COMMIT;
    END LOOP;
END;
/

-- @NODE1
-- Delete some rows
DELETE FROM TEST_RAC_LOB_LS WHERE id BETWEEN 16 AND 20;
COMMIT;

-- @NODE2
-- Delete some rows
DELETE FROM TEST_RAC_LOB_LS WHERE id BETWEEN 116 AND 120;
COMMIT;
