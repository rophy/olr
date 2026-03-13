-- rac-multi-ddl.rac.sql: ALTER TABLE on multiple tables from different nodes.
-- @TAG rac
-- Tests OLR's schema tracking when ALTER TABLE operations occur on different
-- tables from different RAC nodes, interleaved with DML that uses the new schemas.
-- Tables are created in SETUP so they exist at checkpoint time; DDL after
-- checkpoint is ALTER (add columns) from cross-node contexts.
-- @DDL

-- @SETUP
DECLARE
    v_table_exists NUMBER;
BEGIN
    FOR t IN (SELECT table_name FROM user_tables
              WHERE table_name IN ('TEST_RAC_MDDL_A', 'TEST_RAC_MDDL_B')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' PURGE';
    END LOOP;
END;
/

CREATE TABLE TEST_RAC_MDDL_A (
    id   NUMBER PRIMARY KEY,
    name VARCHAR2(100)
);
ALTER TABLE TEST_RAC_MDDL_A ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

CREATE TABLE TEST_RAC_MDDL_B (
    id   NUMBER PRIMARY KEY,
    val  NUMBER
);
ALTER TABLE TEST_RAC_MDDL_B ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- @NODE1
-- Node 1: initial DML on both tables
INSERT INTO TEST_RAC_MDDL_A VALUES (1, 'Alice');
INSERT INTO TEST_RAC_MDDL_A VALUES (2, 'Bob');
INSERT INTO TEST_RAC_MDDL_B VALUES (1, 100);
COMMIT;

-- @NODE2
-- Node 2: DML on both tables
INSERT INTO TEST_RAC_MDDL_A VALUES (3, 'Charlie');
INSERT INTO TEST_RAC_MDDL_B VALUES (2, 200);
INSERT INTO TEST_RAC_MDDL_B VALUES (3, 300);
COMMIT;

-- @NODE1
-- Node 1: ALTER table B (adding a column), then DML using new schema
ALTER TABLE TEST_RAC_MDDL_B ADD (description VARCHAR2(200));

UPDATE TEST_RAC_MDDL_B SET description = 'Added by N1' WHERE id = 1;
INSERT INTO TEST_RAC_MDDL_B VALUES (4, 400, 'New row with desc from N1');
COMMIT;

-- @NODE2
-- Node 2: ALTER table A (adding a column), then DML using new schema
ALTER TABLE TEST_RAC_MDDL_A ADD (email VARCHAR2(200));

UPDATE TEST_RAC_MDDL_A SET email = 'alice@n2.com' WHERE id = 1;
INSERT INTO TEST_RAC_MDDL_A VALUES (4, 'Diana', 'diana@n2.com');
COMMIT;

-- @NODE1
-- Node 1: DML using table A's new schema (altered by node 2)
UPDATE TEST_RAC_MDDL_A SET email = 'bob@n1.com' WHERE id = 2;
COMMIT;

-- Node 1: ALTER table A again (second column addition)
ALTER TABLE TEST_RAC_MDDL_A ADD (department VARCHAR2(100));

INSERT INTO TEST_RAC_MDDL_A VALUES (5, 'Eve', 'eve@n1.com', 'Engineering');
COMMIT;

-- @NODE2
-- Node 2: DML using table B's new schema (altered by node 1)
-- and table A's newest schema (altered twice)
UPDATE TEST_RAC_MDDL_B SET description = 'Updated by N2' WHERE id = 2;
INSERT INTO TEST_RAC_MDDL_A VALUES (6, 'Frank', 'frank@n2.com', 'Sales');
COMMIT;

-- @NODE1
-- Final: deletes across both tables
DELETE FROM TEST_RAC_MDDL_A WHERE id = 3;
DELETE FROM TEST_RAC_MDDL_B WHERE id = 3;
COMMIT;

-- @NODE2
DELETE FROM TEST_RAC_MDDL_A WHERE id = 4;
DELETE FROM TEST_RAC_MDDL_B WHERE id = 4;
COMMIT;
