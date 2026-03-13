-- empty-string-null.sql: Test Oracle's empty string = NULL semantics.
-- Oracle treats '' (empty string) as NULL. Verifies that OLR correctly
-- handles this in INSERTs, UPDATEs, and before/after images.

SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET ECHO OFF

-- Setup: drop and recreate table
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_EMPTY_STR';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_EMPTY_STR PURGE';
    END IF;
END;
/

CREATE TABLE TEST_EMPTY_STR (
    id         NUMBER PRIMARY KEY,
    col_vc     VARCHAR2(100),
    col_char   CHAR(10),
    col_num    NUMBER,
    col_date   DATE
);

ALTER TABLE TEST_EMPTY_STR ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Record start SCN
DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- DML: INSERT with empty strings (Oracle treats as NULL)
INSERT INTO TEST_EMPTY_STR VALUES (1, '', '', NULL, NULL);
COMMIT;

-- DML: INSERT with actual values for comparison
INSERT INTO TEST_EMPTY_STR VALUES (2, 'hello', 'world     ', 42, TO_DATE('2025-06-15', 'YYYY-MM-DD'));
COMMIT;

-- DML: INSERT with mix of empty and non-empty
INSERT INTO TEST_EMPTY_STR VALUES (3, 'text', '', 0, NULL);
COMMIT;

-- DML: UPDATE value to empty string (becomes NULL)
UPDATE TEST_EMPTY_STR SET col_vc = '', col_num = NULL WHERE id = 2;
COMMIT;

-- DML: UPDATE NULL/empty to real value
UPDATE TEST_EMPTY_STR SET col_vc = 'was empty', col_char = 'filled    ', col_num = 99 WHERE id = 1;
COMMIT;

-- DML: UPDATE with single space (NOT empty — should be preserved)
UPDATE TEST_EMPTY_STR SET col_vc = ' ', col_char = '          ' WHERE id = 3;
COMMIT;

-- DML: DELETE
DELETE FROM TEST_EMPTY_STR WHERE id = 1;
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
