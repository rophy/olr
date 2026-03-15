-- rac-partitioned.rac.sql: Partitioned table DML from both RAC nodes.
-- @TAG rac
-- Tests OLR's ability to handle DML on the same partitioned table from
-- different RAC nodes. Verifies redo from different threads targeting
-- different partitions is correctly captured and ordered.

-- @SETUP
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_RAC_PART';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_RAC_PART PURGE';
    END IF;
END;
/

CREATE TABLE TEST_RAC_PART (
    id     NUMBER PRIMARY KEY,
    region VARCHAR2(20),
    name   VARCHAR2(100),
    val    NUMBER
)
PARTITION BY LIST (region) (
    PARTITION p_east  VALUES ('EAST'),
    PARTITION p_west  VALUES ('WEST'),
    PARTITION p_other VALUES (DEFAULT)
);

ALTER TABLE TEST_RAC_PART ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- @NODE1
-- Node 1 inserts into EAST partition
INSERT INTO TEST_RAC_PART VALUES (1, 'EAST', 'N1-East-A', 100);
INSERT INTO TEST_RAC_PART VALUES (2, 'EAST', 'N1-East-B', 200);
COMMIT;

-- @NODE2
-- Node 2 inserts into WEST partition
INSERT INTO TEST_RAC_PART VALUES (3, 'WEST', 'N2-West-A', 300);
INSERT INTO TEST_RAC_PART VALUES (4, 'WEST', 'N2-West-B', 400);
COMMIT;

-- @NODE1
-- Node 1 inserts into WEST partition (cross-partition from node 1)
INSERT INTO TEST_RAC_PART VALUES (5, 'WEST', 'N1-West-C', 500);
-- Node 1 inserts into DEFAULT partition
INSERT INTO TEST_RAC_PART VALUES (6, 'NORTH', 'N1-Other', 600);
COMMIT;

-- @NODE2
-- Node 2 inserts into EAST partition (cross-partition from node 2)
INSERT INTO TEST_RAC_PART VALUES (7, 'EAST', 'N2-East-C', 700);
-- Node 2 inserts into DEFAULT partition
INSERT INTO TEST_RAC_PART VALUES (8, 'SOUTH', 'N2-Other', 800);
COMMIT;

-- @NODE1
-- Node 1 updates rows in WEST partition (inserted by node 2)
UPDATE TEST_RAC_PART SET val = 350, name = 'N1-updated-N2' WHERE id = 3;
COMMIT;

-- @NODE2
-- Node 2 updates rows in EAST partition (inserted by node 1)
UPDATE TEST_RAC_PART SET val = 150, name = 'N2-updated-N1' WHERE id = 1;
COMMIT;

-- @NODE1
-- Node 1 deletes from WEST partition
DELETE FROM TEST_RAC_PART WHERE id = 5;
COMMIT;

-- @NODE2
-- Node 2 deletes from EAST partition
DELETE FROM TEST_RAC_PART WHERE id = 7;
COMMIT;
