CREATE OR REPLACE PROCEDURE TM_CZ.I2B2_BACKOUT_TRIAL(CHARACTER VARYING(50), BIGINT)
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
	trial_id 		alias for $1;
	currentJobID 	alias for $2;
	
	TrialID	varchar(100);
	sqlText	varchar(1000);
	source_table	varchar(50);
	release_table	varchar(50);
	v_tableOwner		varchar(50);
	v_tableName		varchar(50);
	pExists			int4;
	pCount			int4;
	rowCt			int4;
	topNode			varchar(2000);
	v_sso_id		numeric(18,0);
	v_sqlerrm		varchar(1000);
  
	--Audit variables
	newJobFlag int4;
	databaseName VARCHAR(100);
	procedureName VARCHAR(100);
	jobID numeric(18,0);
	stepCt numeric(18,0);
  
	backout_tables		record;

BEGIN

	TrialId := upper(trial_id);
  
	stepCt := 0;
	
	--Set Audit Parameters
	newJobFlag := 0; -- False (Default)
	jobID := currentJobID;

	databaseName := 'TM_CZ';
	procedureName := 'I2B2_BACKOUT_TRIAL';

	--Audit JOB Initialization
	--If Job ID does not exist, then this is a single procedure run and we need to create it
	IF(jobID IS NULL or jobID < 1)
	THEN
		newJobFlag := 1; -- True
		jobId := tm_cz.czx_start_audit (procedureName, databaseName);
	END IF;
  
	if TrialId is null
	then 
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'TrialId missing/invalid',0,stepCt,'Done');
		Return 0;
	end if;

	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Start procedure ' || procedureName,0,stepCt,'Done');

	--	get top node for study
	
	select min(c_fullname) into topNode
		from i2b2metadata.i2b2
		where sourcesystem_cd = TrialId;

	--	delete study from object or user security tables, do this first because search_secure_object in migrate_tables
	
	select count(*) into pExists
	from searchapp.search_secure_object
	where bio_data_unique_id = 'EXP:' || TrialId;
	
	if pExists > 0 then
		select search_secure_object_id into v_sso_id
		from searchapp.search_secure_object
		where bio_data_unique_id = 'EXP:' || TrialId;
		
		--	delete security for object
		
		delete from searchapp.search_auth_sec_object_access
		where secure_object_id = v_sso_id;
		rowCt := ROW_COUNT;
		stepCt := stepCt + 1;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Removed study secure object id from search_auth_sec_object_access',1,stepCt,'Done');
		
		--	delete security links between users and study
		
		delete from searchapp.search_auth_user_sec_access
		where search_secure_object_id = v_sso_id;
		rowCt := ROW_COUNT;
		stepCt := stepCt + 1;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Removed study secure object id from search_auth_user_sec_access',1,stepCt,'Done');
	end if;		
	--	load study-specific table names from tm_cz.migrate_tables
	
	for backout_tables in
		select upper(table_owner) as table_owner
			  ,upper(table_name) as table_name
			  ,upper(study_specific) as study_specific
			  ,where_clause
			  ,upper(stage_table_name) as stage_table_name
			  ,upper(coalesce(rebuild_index,'N')) as rebuild_index
		from tm_cz.migrate_tables
		where upper(study_specific) = 'Y'
	loop
		--	setup variables
		
		source_table := backout_tables.table_owner || '.' || backout_tables.table_name;
		v_tableName := backout_tables.table_name;
		v_tableOwner := backout_tables.table_owner;
		stepCt := stepCt + 1;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Processing ' || source_table,0,stepCt,'Done');
		
		select count(*) into pExists
		from _v_table
		where tableName = v_tableName
		  and schema = v_tableOwner
		  and upper(objtype) = 'TABLE';
		  
		if pExists > 0 then 
			--	delete study from tables
			
			sqlText := 'delete from ' || source_table || ' st ' || replace(backout_tables.where_clause,'TrialId','''' || TrialId || '''');
			execute immediate sqlText;
			rowCt := ROW_COUNT;
			stepCt := stepCt + 1;
			call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Deleted study from ' || source_table,rowCt,stepCt,'Done');
		end if;
	end loop;
	
	--	delete any data for study in modifier_dimension, modifier_metadata
	
	delete from i2b2demodata.modifier_dimension
	where sourcesystem_cd = trialId;
	rowCt := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete data for trial from modifier_dimension',rowCt,stepCt,'Done');
	
	delete from i2b2demodata.modifier_metadata
	where modifier_cd = 'STUDY:' || trialId;
	rowCt := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete data for trial from modifier_metadata',rowCt,stepCt,'Done');
	
	--	delete tm_lz clinical data
	
	delete from tm_lz.lz_src_clinical_data
	where study_id = trialId;
	rowCt := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete data for trial from lz_src_clinical_data',rowCt,stepCt,'Done');
	
	--	delete tm_lz study metadata
	
	delete from tm_lz.lz_src_study_metadata
	where study_id = trialId;
	rowCt := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete data for trial from lz_src_study_metadata',rowCt,stepCt,'Done');

	--	reload i2b2_secure
	
	call tm_cz.i2b2_load_security_data(jobId);
	
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'End procedure ' || procedureName,rowCt,stepCt,'Done');
  
    ---Cleanup OVERALL JOB if this proc is being run standalone
	IF newJobFlag = 1
	THEN
		call tm_cz.czx_end_audit (jobID, 'SUCCESS');
	END IF;
	
	return 0;

	EXCEPTION
	WHEN OTHERS THEN
		v_sqlerrm := SQLERRM;
		raise notice 'error: %', v_sqlerrm;
		--Handle errors.
		call tm_cz.czx_error_handler (jobID, procedureName, v_sqlerrm);
		--End Proc
		call tm_cz.czx_end_audit (jobID, 'FAIL');
		return 16;
  
END;

 
END_PROC;

