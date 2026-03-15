-- nchar-nclob.sql: Test national character set types (NCHAR, NVARCHAR2, NCLOB).
-- Run as PDB user (e.g., olr_test/olr_test@//localhost:1521/FREEPDB1)
--
-- NCHAR/NVARCHAR2/NCLOB use the national character set (typically AL16UTF16)
-- instead of the database character set. OLR handles these via charsetForm=2
-- with the same code paths as CHAR/VARCHAR2/CLOB but using the national charset.
--
-- Outputs: FIXTURE_SCN_START: <scn> and FIXTURE_SCN_END: <scn>

SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET ECHO OFF

-- Setup: drop and recreate table
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_NCHAR';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_NCHAR PURGE';
    END IF;
END;
/

CREATE TABLE TEST_NCHAR (
    id            NUMBER PRIMARY KEY,
    col_nchar     NCHAR(50),
    col_nvarchar2 NVARCHAR2(200),
    col_nclob     NCLOB,
    col_label     VARCHAR2(50)
);

ALTER TABLE TEST_NCHAR ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Record start SCN
DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- DML: INSERT with ASCII content
INSERT INTO TEST_NCHAR VALUES (1, N'hello', N'world', N'Short NCLOB text', 'ascii');
COMMIT;

-- DML: INSERT with Unicode content (CJK, emoji-safe, accented)
INSERT INTO TEST_NCHAR VALUES (2, N'日本語テスト', N'Ünïcödé tëxt', N'中文NCLOB内容测试', 'unicode');
COMMIT;

-- DML: INSERT with NULL national charset columns
INSERT INTO TEST_NCHAR VALUES (3, NULL, NULL, NULL, 'all-null-nchar');
COMMIT;

-- DML: INSERT with empty string (Oracle treats as NULL)
INSERT INTO TEST_NCHAR VALUES (4, N'', N'', N'', 'empty-string');
COMMIT;

-- DML: UPDATE NCHAR columns — value to different value
UPDATE TEST_NCHAR SET
    col_nchar = N'updated',
    col_nvarchar2 = N'변경된 텍스트',
    col_nclob = N'Updated NCLOB content with special chars: é à ü'
WHERE id = 1;
COMMIT;

-- DML: UPDATE NULL to value
UPDATE TEST_NCHAR SET
    col_nchar = N'was null',
    col_nvarchar2 = N'now has value',
    col_nclob = N'NCLOB was null, now populated'
WHERE id = 3;
COMMIT;

-- DML: UPDATE value to NULL
UPDATE TEST_NCHAR SET
    col_nchar = NULL,
    col_nvarchar2 = NULL,
    col_nclob = NULL
WHERE id = 2;
COMMIT;

-- DML: DELETE rows
DELETE FROM TEST_NCHAR WHERE id = 4;
COMMIT;

DELETE FROM TEST_NCHAR WHERE id = 2;
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
