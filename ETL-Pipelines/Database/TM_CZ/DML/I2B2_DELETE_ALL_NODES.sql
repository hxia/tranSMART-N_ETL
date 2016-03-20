CREATE OR REPLACE PROCEDURE TM_CZ.I2B2_DELETE_ALL_NODES(VARCHAR(ANY), INTEGER)
RETURNS INTEGER
LANGUAGE NZPLSQL AS
BEGIN_PROC
DECLARE
	INPUT_PATH ALIAS FOR $1;
	CURRENTJOBID ALIAS FOR $2;
	
	--Audit variables
	newJobFlag int4;
	databaseName VARCHAR(100);
	procedureName VARCHAR(100);
	jobID numeric(18,0);
	stepCt numeric(18,0);
	
	studyId		varchar(100);
	topNode		varchar(1000);
	parentNode	varchar(1000);
	pExists		int4;
	
BEGIN

  --Set Audit Parameters
  newJobFlag := 0; -- False (Default)
  jobID := currentJobID;

--	SELECT sys_context('USERENV', 'CURRENT_SCHEMA') INTO databaseName FROM dual;
--	procedureName := $$PLSQL_UNIT;
	databaseName := 'TM_CZ';
	procedureName := 'I2B2_DELETE_ALL_NODES';  

  --Audit JOB Initialization
  --If Job ID does not exist, then this is a single procedure run and we need to create it
  IF(jobID IS NULL or jobID < 1)
  THEN
    newJobFlag := 1; -- True
    jobId := TM_CZ.czx_start_audit (procedureName, databaseName);
  END IF;
    	
	stepCt := 0;
	stepct := stepct + 1;
	CALL TM_CZ.czx_write_audit(jobid,databasename,procedurename,'Starting procedure '||procedureName,0,stepct,'done');

	if coalesce(input_path,'') = ''  or input_path = '%'
		then 
			CALL TM_CZ.czx_write_audit(jobId,databaseName,procedureName,'Path missing or invalid',0,stepCt,'Done'); 
	else 
		select count(*) into pExists
		from i2b2metadata.i2b2
		where c_fullname = input_path;
		
		if pExists = 0 then
			raise invalid_path;
		end if;
		
		select sourcesystem_cd into studyId
		from i2b2metadata.i2b2
		where c_fullname = input_path;
		
		select min(c_fullname) into topNode
		from i2b2metadata.i2b2
		where sourcesystem_cd = studyId;
		
		stepct := stepct + 1;
		CALL TM_CZ.czx_write_audit(jobid,databasename,procedurename,'Study: ' || studyId || ' Node: ' || input_path,0,stepct,'done');
				
		parentNode := substr(input_path,1,instr(input_path,'\',-2));
		stepct := stepct + 1;
		
		CALL TM_CZ.czx_write_audit(jobid,databasename,procedurename,'topNode: '|| topNode || ' parentNode: ' || parentNode,0,stepct,'done');
		
		--observation_fact
		
		delete from i2b2demodata.observation_fact f
		where f.concept_cd in (select x.c_basecode from i2b2metadata.i2b2 x where x.c_fullname like input_path || '%' escape '');
		stepct := stepct + 1;
		CALL TM_CZ.czx_write_audit(jobid,databasename,procedurename,'delete data for trial from i2b2demodata observation_fact',1/*sql%rowcount*/,stepct,'done');
		
		--concept dimension
		
		delete from i2b2demodata.concept_dimension c
		where c.concept_path like input_path || '%' escape '';
		stepct := stepct + 1;
		CALL TM_CZ.czx_write_audit(jobid,databasename,procedurename,'delete data for trial from i2b2demodata concept_dimension',1/*sql%rowcount*/,stepct,'done');
		
		--i2b2
		delete from i2b2metadata.i2b2 i
		where i.c_fullname like input_path || '%' escape '';
		stepct := stepct + 1;
		CALL TM_CZ.czx_write_audit(jobid,databasename,procedurename,'delete data for trial from i2b2metadata i2b2',1/*sql%rowcount*/,stepct,'done');
		commit;
	  
		--i2b2_secure
		delete from i2b2metadata.i2b2_secure s
		where s.c_fullname like input_path || '%' escape '';
		stepct := stepct + 1;
		CALL TM_CZ.czx_write_audit(jobid,databasename,procedurename,'delete data for trial from i2b2metadata i2b2_secure',1/*sql%rowcount*/,stepct,'done');

		--concept_counts
	
		if parentNode >= topNode then
			call tm_cz.i2b2_create_concept_counts(parentNode,jobId);
		else
			delete from i2b2demodata.concept_counts
			where concept_path like input_path || '%' escape '';
			stepct := stepct + 1;
			CALL TM_CZ.czx_write_audit(jobid,databasename,procedurename,'delete data for trial from i2b2demodata concept_counts',1/*sql%rowcount*/,stepct,'done');
		end if;
    end if;
	
    ---Cleanup OVERALL JOB if this proc is being run standalone
  IF newJobFlag = 1
  THEN
    CALL TM_CZ.czx_end_audit (jobID, 'SUCCESS');
  END IF;

  EXCEPTION
  WHEN OTHERS THEN
    --Handle errors.
    --czx_error_handler (jobID, procedureName);
    --End Proc
    CALL TM_CZ.czx_end_audit (jobID, 'FAIL');
END;

END_PROC;
