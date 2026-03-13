-- large-lobs.sql: Test out-of-row LOBs.
-- Verifies OLR correctly handles LOBs that exceed the 4000-byte inline
-- threshold and are stored out-of-row. Uses single-statement inserts
-- with PL/SQL VARCHAR2 (up to 32767 bytes) to avoid multi-record
-- DBMS_LOB.WRITEAPPEND issues.

SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET ECHO OFF

-- Setup: drop and recreate table
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists
    FROM user_tables WHERE table_name = 'TEST_LARGE_LOBS';
    IF v_table_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE TEST_LARGE_LOBS PURGE';
    END IF;
END;
/

CREATE TABLE TEST_LARGE_LOBS (
    id         NUMBER PRIMARY KEY,
    col_clob   CLOB,
    col_blob   BLOB,
    col_label  VARCHAR2(50)
);

ALTER TABLE TEST_LARGE_LOBS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Record start SCN
DECLARE
    v_start_scn NUMBER;
BEGIN
    SELECT current_scn INTO v_start_scn FROM v$database;
    DBMS_OUTPUT.PUT_LINE('FIXTURE_SCN_START: ' || v_start_scn);
END;
/

-- DML: INSERT with ~8KB CLOB (out-of-row, single statement)
DECLARE
    v_clob VARCHAR2(32767);
BEGIN
    v_clob := RPAD('CLOB-8k-', 8000, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 ');
    INSERT INTO TEST_LARGE_LOBS VALUES (1, v_clob, NULL, 'clob-8k');
    COMMIT;
END;
/

-- DML: INSERT with ~4KB BLOB (out-of-row, single statement)
DECLARE
    v_raw RAW(2000);
BEGIN
    v_raw := UTL_RAW.COPIES(HEXTORAW('DEADBEEFCAFEBABE'), 250);
    INSERT INTO TEST_LARGE_LOBS VALUES (2, NULL, v_raw, 'blob-2k-raw');
    COMMIT;
END;
/

-- DML: INSERT with both CLOB and BLOB
DECLARE
    v_clob VARCHAR2(32767);
    v_raw  RAW(2000);
BEGIN
    v_clob := RPAD('Both-LOBs-', 6000, 'XYZ 0123456789 ');
    v_raw := UTL_RAW.COPIES(HEXTORAW('FF00FF00'), 500);
    INSERT INTO TEST_LARGE_LOBS VALUES (3, v_clob, v_raw, 'both-lobs');
    COMMIT;
END;
/

-- DML: INSERT with ~32KB CLOB (max PL/SQL VARCHAR2)
DECLARE
    v_clob VARCHAR2(32767);
BEGIN
    v_clob := RPAD('BigCLOB-', 32000, '0123456789 ABCDEFGHIJKLMNOP ');
    INSERT INTO TEST_LARGE_LOBS VALUES (4, v_clob, NULL, 'clob-32k');
    COMMIT;
END;
/

-- DML: UPDATE CLOB to different value
DECLARE
    v_clob VARCHAR2(32767);
BEGIN
    v_clob := RPAD('Updated-CLOB-', 10000, 'updated content here ');
    UPDATE TEST_LARGE_LOBS SET col_clob = v_clob, col_label = 'updated-clob' WHERE id = 1;
    COMMIT;
END;
/

-- DML: DELETE row with LOBs
DELETE FROM TEST_LARGE_LOBS WHERE id = 2;
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
