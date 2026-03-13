-- rac-log-switch.rac.sql: DML spanning multiple redo log files on both nodes.
-- @TAG rac
-- Tests OLR's per-thread log switch handling when redo logs wrap around.
-- Generates enough redo volume to naturally cause log switches, then verifies
-- that DML from both nodes is still captured correctly across log boundaries.

-- @SETUP
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_RAC_LOGSWITCH';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_RAC_LOGSWITCH PURGE';
    END IF;
END;
/

CREATE TABLE TEST_RAC_LOGSWITCH (
    id    NUMBER PRIMARY KEY,
    phase VARCHAR2(200),
    val   NUMBER
);

ALTER TABLE TEST_RAC_LOGSWITCH ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- Phase 1: Small DML on both nodes

-- @NODE1
INSERT INTO TEST_RAC_LOGSWITCH VALUES (1, 'pre-bulk-n1', 100);
INSERT INTO TEST_RAC_LOGSWITCH VALUES (2, 'pre-bulk-n1', 200);
COMMIT;

-- @NODE2
INSERT INTO TEST_RAC_LOGSWITCH VALUES (3, 'pre-bulk-n2', 300);
COMMIT;

-- Phase 2: Large bulk insert on node 1 to generate redo volume

-- @NODE1
BEGIN
    FOR i IN 100..399 LOOP
        INSERT INTO TEST_RAC_LOGSWITCH VALUES (i, 'bulk-n1-' || LPAD(TO_CHAR(i), 10, 'X'), i * 10);
    END LOOP;
    COMMIT;
END;
/

-- Phase 3: DML on node 2 while node 1 has generated lots of redo

-- @NODE2
INSERT INTO TEST_RAC_LOGSWITCH VALUES (4, 'mid-bulk-n2', 400);
UPDATE TEST_RAC_LOGSWITCH SET val = 301, phase = 'updated-n2' WHERE id = 3;
COMMIT;

-- Phase 4: More bulk on node 1

-- @NODE1
BEGIN
    FOR i IN 400..599 LOOP
        INSERT INTO TEST_RAC_LOGSWITCH VALUES (i, 'bulk-n1-' || LPAD(TO_CHAR(i), 10, 'X'), i * 10);
    END LOOP;
    COMMIT;
END;
/

-- Phase 5: Final DML on both nodes after all the redo volume

-- @NODE1
UPDATE TEST_RAC_LOGSWITCH SET val = 101, phase = 'final-n1' WHERE id = 1;
DELETE FROM TEST_RAC_LOGSWITCH WHERE id = 2;
COMMIT;

-- @NODE2
INSERT INTO TEST_RAC_LOGSWITCH VALUES (5, 'final-n2', 500);
DELETE FROM TEST_RAC_LOGSWITCH WHERE id = 4;
COMMIT;
