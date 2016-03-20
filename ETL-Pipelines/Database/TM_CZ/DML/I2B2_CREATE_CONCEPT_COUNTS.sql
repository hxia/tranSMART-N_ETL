CREATE OR REPLACE PROCEDURE TM_CZ.I2B2_CREATE_CONCEPT_COUNTS(CHARACTER VARYING(2000), BIGINT)
RETURNS INTEGER
LANGUAGE NZPLSQL AS
BEGIN_PROC
/*************************************************************************
* Copyright 2008-2012 Janssen Research & Development, LLC.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
******************************************************************/
Declare
	--	Alias for parameters
	input_path alias for $1;
	currentJobID alias for $2;
	
	--Audit variables
	newJobFlag int4;
	databaseName VARCHAR(100);
	procedureName VARCHAR(100);
	jobID numeric(18,0);
	stepCt numeric(18,0);
	rowCount	numeric(18,0);
  
	bslash char(1);
	v_sqlerrm	varchar(1000);
  
BEGIN
     
	--Set Audit Parameters
	newJobFlag := 0; -- False (Default)
	jobID := currentJobID;

	databaseName := 'TM_CZ';
	procedureName := 'I2B2_CREATE_CONCEPT_COUNTS';

	--Audit JOB Initialization
	--If Job ID does not exist, then this is a single procedure run and we need to create it
	IF(jobID IS NULL or jobID < 1)
	THEN
		newJobFlag := 1; -- True
		jobId := tm_cz.czx_start_audit (procedureName, databaseName);
	END IF;
    	
	stepCt := 0;
	bslash := '\\';
  
	delete from i2b2demodata.concept_counts
	where concept_path like input_path || '%' escape '';
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete counts for trial from I2B2DEMODATA concept_counts',rowCount,stepCt,'Done');
	
	--	Join each node (folder or leaf) in the path to it's leaf in the work table to count patient numbers

	insert into i2b2demodata.concept_counts
	(concept_path
	,parent_concept_path
	,patient_count
	)
	select fa.c_fullname
		  ,ltrim(SUBSTR(fa.c_fullname, 1,instr(fa.c_fullname, bslash,-1,2)))
		  ,count(distinct tpm.patient_num)
	from i2b2metadata.i2b2 fa
	    ,i2b2metadata.i2b2 la
		,i2b2demodata.observation_fact tpm
		,i2b2demodata.patient_dimension p
	where fa.c_fullname like input_path || '%' escape ''
	  and substr(fa.c_visualattributes,2,1) != 'H'
	  and la.c_fullname like fa.c_fullname || '%' escape ''
	  and la.c_visualattributes like 'L%'
	  and tpm.patient_num = p.patient_num
	  and la.c_basecode = tpm.concept_cd
	group by fa.c_fullname
			,ltrim(SUBSTR(fa.c_fullname, 1,instr(fa.c_fullname, bslash,-1,2)));	
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert counts for trial into I2B2DEMODATA concept_counts',rowCount,stepCt,'Done');
	
	--SET ANY NODE WITH MISSING OR ZERO COUNTS TO HIDDEN

	update i2b2metadata.i2b2 a
	set c_visualattributes = substr(a.c_visualattributes,1,1) || 'H' || substr(a.c_visualattributes,3,1)
	from (select b.c_fullname
	      from i2b2metadata.i2b2 b
		  where b.c_fullname like input_path || '%' escape ''
		    and not exists
			   (select 1 from i2b2demodata.concept_counts nc
			    where b.c_fullname = nc.concept_path)
		  union
		  select zc.concept_path as c_fullname
		  from i2b2demodata.concept_counts zc
		  where zc.concept_path like input_path || '%' escape ''
		    and zc.patient_count = 0) upd
	where a.c_fullname = upd.c_fullname
		and c_name != 'SECURITY';
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Nodes hidden with missing/zero counts for trial into I2B2DEMODATA concept_counts',rowCount,stepCt,'Done');
	
    ---Cleanup OVERALL JOB if this proc is being run standalone
	IF newJobFlag = 1
	THEN
		call tm_cz.czx_end_audit (jobID, 'SUCCESS');
	END IF;
	
	return 0;

	EXCEPTION
	WHEN OTHERS THEN
		v_sqlerrm := substr(SQLERRM,1,1000);
		raise notice 'error: %', v_sqlerrm;
		--Handle errors.
		call tm_cz.czx_error_handler (jobID, procedureName,v_sqlerrm);
		--End Proc
		call tm_cz.czx_end_audit (jobID, 'FAIL');
		return 16;
END;
END_PROC;

