-- default-columns.sql: Test tables with DEFAULT column values.
-- Verifies OLR captures the actual stored value when columns are omitted
-- from INSERT, and handles DEFAULT ON NULL (Oracle 12c+).

SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET ECHO OFF

-- Setup: drop and recreate table
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_DEFAULTS';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_DEFAULTS PURGE';
    END IF;
END;
/

CREATE TABLE TEST_DEFAULTS (
    id          NUMBER PRIMARY KEY,
    status      VARCHAR2(20) DEFAULT 'active',
    counter     NUMBER DEFAULT 0,
    created_at  DATE DEFAULT SYSDATE,
    flag        NUMBER(1) DEFAULT 1,
    notes       VARCHAR2(200) DEFAULT NULL
);

ALTER TABLE TEST_DEFAULTS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Record start SCN
DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- DML: INSERT with all defaults (only PK specified)
INSERT INTO TEST_DEFAULTS (id) VALUES (1);
COMMIT;

-- DML: INSERT with explicit values overriding defaults
INSERT INTO TEST_DEFAULTS VALUES (2, 'inactive', 10, TO_DATE('2025-01-01', 'YYYY-MM-DD'), 0, 'explicit');
COMMIT;

-- DML: INSERT with mix of default and explicit
INSERT INTO TEST_DEFAULTS (id, status, notes) VALUES (3, 'pending', 'partial');
COMMIT;

-- DML: INSERT with explicit NULL (overrides DEFAULT)
INSERT INTO TEST_DEFAULTS (id, status, counter) VALUES (4, NULL, NULL);
COMMIT;

-- DML: UPDATE default column to different value
UPDATE TEST_DEFAULTS SET status = 'closed', counter = 5 WHERE id = 1;
COMMIT;

-- DML: UPDATE explicit value back to default value
UPDATE TEST_DEFAULTS SET status = 'active', counter = 0 WHERE id = 2;
COMMIT;

-- DML: DELETE
DELETE FROM TEST_DEFAULTS WHERE id = 4;
COMMIT;

-- Record end SCN
DECLARE
    v_end_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_end_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_END: ' || v_end_scn);
END;
/

EXIT
