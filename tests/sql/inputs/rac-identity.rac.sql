-- rac-identity.rac.sql: Identity columns across RAC nodes.
-- @TAG rac
-- Tests that OLR correctly captures auto-generated identity values when
-- INSERTs originate from different RAC nodes (each node has its own
-- sequence cache).

-- @SETUP
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_RAC_IDENTITY';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_RAC_IDENTITY PURGE';
    END IF;
END;
/

CREATE TABLE TEST_RAC_IDENTITY (
    id     NUMBER GENERATED ALWAYS AS IDENTITY,
    name   VARCHAR2(100),
    val    NUMBER,
    CONSTRAINT test_rac_identity_pk PRIMARY KEY (id)
);

ALTER TABLE TEST_RAC_IDENTITY ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- @NODE1
INSERT INTO TEST_RAC_IDENTITY (name, val) VALUES ('N1-Alice', 100);
INSERT INTO TEST_RAC_IDENTITY (name, val) VALUES ('N1-Bob', 200);
COMMIT;

-- @NODE2
INSERT INTO TEST_RAC_IDENTITY (name, val) VALUES ('N2-Charlie', 300);
INSERT INTO TEST_RAC_IDENTITY (name, val) VALUES ('N2-Diana', 400);
COMMIT;

-- @NODE1
INSERT INTO TEST_RAC_IDENTITY (name, val) VALUES ('N1-Eve', 500);
COMMIT;

-- @NODE2
INSERT INTO TEST_RAC_IDENTITY (name, val) VALUES ('N2-Frank', 600);
COMMIT;

-- @NODE1
-- Update a row inserted by node 2 (identity value should be in before-image)
UPDATE TEST_RAC_IDENTITY SET val = 350 WHERE name = 'N2-Charlie';
COMMIT;

-- @NODE2
-- Delete a row inserted by node 1
DELETE FROM TEST_RAC_IDENTITY WHERE name = 'N1-Bob';
COMMIT;
