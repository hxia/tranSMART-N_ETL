CREATE OR REPLACE PROCEDURE TM_CZ.CZX_WRITE_ERROR(bigint, character varying(any), character varying(any),character varying(any), character varying(any))
RETURNS INTEGER
EXECUTE AS OWNER
LANGUAGE NZPLSQL AS
BEGIN_PROC
DECLARE
	JOBID ALIAS FOR $1;
	ERRORNUMBER ALIAS FOR $2;
	ERRORMESSAGE ALIAS FOR $3;
	ERRORSTACK ALIAS FOR $4;
	ERRORBACKTRACE ALIAS FOR $5;
BEGIN

	INSERT INTO TM_CZ.CZ_JOB_ERROR(
		JOB_ID,
		ERROR_NUMBER,
		ERROR_MESSAGE,
		ERROR_STACK,
    ERROR_BACKTRACE,
		SEQ_ID)
	SELECT
		JOBID,
		ERRORNUMBER,
		ERRORMESSAGE,
		ERRORSTACK,
    ERRORBACKTRACE,
		(select MAX(SEQ_ID) from TM_CZ.CZ_JOB_AUDIT WHERE JOB_ID=JOBID)
  FROM 
    TM_CZ.CZ_JOB_AUDIT 
  WHERE 
    JOB_ID=JOBID;

RETURN 0;
  exception 
	when OTHERS then
	RAISE NOTICE 'Exception Raised: %', SQLERRM;
END;
END_PROC;