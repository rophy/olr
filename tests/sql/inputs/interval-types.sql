-- interval-types.sql: Test INTERVAL YEAR TO MONTH and INTERVAL DAY TO SECOND.
-- Verifies OLR correctly captures interval data types.

SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET ECHO OFF

-- Setup: drop and recreate table
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_INTERVALS';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_INTERVALS PURGE';
    END IF;
END;
/

CREATE TABLE TEST_INTERVALS (
    id          NUMBER PRIMARY KEY,
    col_ym      INTERVAL YEAR(4) TO MONTH,
    col_ds      INTERVAL DAY(4) TO SECOND(6),
    col_label   VARCHAR2(50)
);

ALTER TABLE TEST_INTERVALS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Record start SCN
DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- DML: INSERT with positive intervals
INSERT INTO TEST_INTERVALS VALUES (1,
    INTERVAL '5-3' YEAR TO MONTH,
    INTERVAL '10 04:30:15.123456' DAY TO SECOND,
    'positive');
COMMIT;

-- DML: INSERT with zero intervals
INSERT INTO TEST_INTERVALS VALUES (2,
    INTERVAL '0-0' YEAR TO MONTH,
    INTERVAL '0 00:00:00.000000' DAY TO SECOND,
    'zero');
COMMIT;

-- DML: INSERT with large intervals
INSERT INTO TEST_INTERVALS VALUES (3,
    INTERVAL '99-11' YEAR TO MONTH,
    INTERVAL '999 23:59:59.999999' DAY TO SECOND,
    'large');
COMMIT;

-- DML: INSERT with negative intervals
INSERT INTO TEST_INTERVALS VALUES (4,
    INTERVAL '-3-6' YEAR TO MONTH,
    INTERVAL '-5 12:30:00.000000' DAY TO SECOND,
    'negative');
COMMIT;

-- DML: INSERT with NULL intervals
INSERT INTO TEST_INTERVALS VALUES (5, NULL, NULL, 'null-intervals');
COMMIT;

-- DML: UPDATE interval values
UPDATE TEST_INTERVALS SET
    col_ym = INTERVAL '1-0' YEAR TO MONTH,
    col_ds = INTERVAL '1 01:01:01.000001' DAY TO SECOND,
    col_label = 'updated'
WHERE id = 1;
COMMIT;

-- DML: DELETE
DELETE FROM TEST_INTERVALS WHERE id = 2;
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
