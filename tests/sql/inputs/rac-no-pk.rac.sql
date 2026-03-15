-- rac-no-pk.rac.sql: No primary key table across RAC nodes.
-- @TAG rac
-- Tests OLR's ROWID-based row identification when DML on a table without
-- a primary key originates from different RAC nodes. Verifies that before-images
-- correctly identify rows across threads.

-- @SETUP
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_RAC_NOPK';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_RAC_NOPK PURGE';
    END IF;
END;
/

CREATE TABLE TEST_RAC_NOPK (
    name    VARCHAR2(100),
    value   NUMBER,
    status  VARCHAR2(20)
);

ALTER TABLE TEST_RAC_NOPK ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- @NODE1
-- Node 1 inserts rows
INSERT INTO TEST_RAC_NOPK VALUES ('Alice', 100, 'active');
INSERT INTO TEST_RAC_NOPK VALUES ('Bob', 200, 'active');
COMMIT;

-- @NODE2
-- Node 2 inserts rows (including duplicate values)
INSERT INTO TEST_RAC_NOPK VALUES ('Charlie', 300, 'active');
INSERT INTO TEST_RAC_NOPK VALUES ('Diana', 400, 'active');
COMMIT;

-- @NODE1
-- Node 1 inserts duplicate row data
INSERT INTO TEST_RAC_NOPK VALUES ('Alice', 100, 'active');
COMMIT;

-- @NODE2
-- Node 2 updates a row it inserted
UPDATE TEST_RAC_NOPK SET value = 350, status = 'updated' WHERE name = 'Charlie';
COMMIT;

-- @NODE1
-- Node 1 updates a row inserted by node 2
UPDATE TEST_RAC_NOPK SET status = 'n1-modified' WHERE name = 'Diana';
COMMIT;

-- @NODE2
-- Node 2 deletes a row inserted by node 1
DELETE FROM TEST_RAC_NOPK WHERE name = 'Bob';
COMMIT;

-- @NODE1
-- Node 1 deletes one of the duplicate Alice rows
DELETE FROM TEST_RAC_NOPK WHERE name = 'Alice' AND ROWNUM = 1;
COMMIT;
