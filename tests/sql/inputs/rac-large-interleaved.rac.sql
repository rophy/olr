-- rac-large-interleaved.rac.sql: Large transaction on one node, small on the other.
-- @TAG rac
-- Tests SCN watermark throttling when one thread produces many pending transactions
-- while the other processes slowly. Exercises the 500-transaction deferral threshold.

-- @SETUP
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_RAC_BULK_A';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_RAC_BULK_A PURGE';
    END IF;
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_RAC_BULK_B';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_RAC_BULK_B PURGE';
    END IF;
END;
/

CREATE TABLE TEST_RAC_BULK_A (
    id   NUMBER PRIMARY KEY,
    data VARCHAR2(200)
);

CREATE TABLE TEST_RAC_BULK_B (
    id   NUMBER PRIMARY KEY,
    data VARCHAR2(200)
);

ALTER TABLE TEST_RAC_BULK_A ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE TEST_RAC_BULK_B ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- @NODE1
-- Large bulk insert on node 1 (single transaction)
BEGIN
    FOR i IN 1..200 LOOP
        INSERT INTO TEST_RAC_BULK_A VALUES (i, 'Node1-row-' || TO_CHAR(i));
    END LOOP;
    COMMIT;
END;
/

-- @NODE2
-- Small inserts on node 2 while node 1's bulk is in redo
INSERT INTO TEST_RAC_BULK_B VALUES (1, 'Node2-small-1');
INSERT INTO TEST_RAC_BULK_B VALUES (2, 'Node2-small-2');
INSERT INTO TEST_RAC_BULK_B VALUES (3, 'Node2-small-3');
COMMIT;

UPDATE TEST_RAC_BULK_B SET data = 'Node2-updated-1' WHERE id = 1;
COMMIT;

DELETE FROM TEST_RAC_BULK_B WHERE id = 3;
COMMIT;

-- @NODE1
-- Node 1 updates some of its bulk rows
UPDATE TEST_RAC_BULK_A SET data = 'Node1-updated' WHERE id <= 5;
COMMIT;

-- @NODE2
-- Node 2 inserts more
INSERT INTO TEST_RAC_BULK_B VALUES (4, 'Node2-small-4');
INSERT INTO TEST_RAC_BULK_B VALUES (5, 'Node2-small-5');
COMMIT;
