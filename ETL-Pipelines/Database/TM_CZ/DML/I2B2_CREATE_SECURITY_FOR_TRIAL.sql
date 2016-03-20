CREATE OR REPLACE PROCEDURE TM_CZ.I2B2_CREATE_SECURITY_FOR_TRIAL(CHARACTER VARYING(50), CHARACTER VARYING(10), BIGINT)
RETURNS int4
LANGUAGE NZPLSQL AS
BEGIN_PROC
/*************************************************************************
* Copyright 2008-2012 Janssen Research and Development, LLC.
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
	trial_id alias for $1;
	secured_study alias for $2;
	currentJobID alias for $3;
 
	TrialID 			varchar(100);
	securedStudy 		varchar(5);
	pExists				int4;
	v_bio_experiment_id	numeric(18,0);
	etlDate				timestamp;
	v_sso_id			numeric(18,0);
	bslash				char(1);
	v_sqlerrm			varchar(1000);
  
	--Audit variables
	newJobFlag int4;
	databaseName VARCHAR(100);
	procedureName VARCHAR(100);
	jobID numeric(18,0);
	stepCt numeric(18,0);
	rowCount		numeric(18,0);

BEGIN
	TrialID := trial_id;
	securedStudy := secured_study;
	select now() into etlDate;
	bslash := '\\';
  
	--Set Audit Parameters
	newJobFlag := 0; -- False (Default)
	jobID := currentJobID;

	databaseName := 'TM_CZ';
	procedureName := 'I2B2_CREATE_SECURITY_FOR_TRIAL';

	--Audit JOB Initialization
	--If Job ID does not exist, then this is a single procedure run and we need to create it
	IF(jobID IS NULL or jobID < 1)
	THEN
		newJobFlag := 1; -- True
		jobId := tm_cz.czx_start_audit (procedureName, databaseName);
	END IF;
  
	stepCt := 0;
  
	delete from i2b2demodata.observation_fact
	where case when modifier_cd = '@'
			   then sourcesystem_cd
			   else modifier_cd end = TrialId
	  and concept_cd = 'SECURITY';
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete security records for trial from I2B2DEMODATA observation_fact',rowCount,stepCt,'Done');

	insert into i2b2demodata.observation_fact
    (patient_num
	,concept_cd
	,provider_id
	,modifier_cd
	,valtype_cd
	,tval_char
	,valueflag_cd
	,location_cd
	,update_date
	,download_date
	,import_date
	,sourcesystem_cd
	,instance_num
	)
	select distinct patient_num
		  ,'SECURITY'
		  ,'@'
		  ,'@'
		  ,'T'
		  ,case when securedStudy = 'N' then 'EXP:PUBLIC' else 'EXP:' || trialID end
		  ,'@'
		  ,'@'
		  ,etlDate
		  ,etlDate
		  ,etlDate
		  ,TrialId
		  ,1
	from i2b2demodata.patient_dimension
	where sourcesystem_cd like TrialID || ':%';
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert security records for trial from I2B2DEMODATA observation_fact',rowCount,stepCt,'Done');
	
	--	insert patients to patient_trial table
	
	delete from i2b2demodata.patient_trial
	where trial  = TrialID;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete data for trial from I2B2DEMODATA patient_trial',rowCount,stepCt,'Done');
  
	insert into i2b2demodata.patient_trial
	(patient_num
	,trial
	,secure_obj_token
	)
	select patient_num, 
		   TrialID,
		   case when securedStudy = 'Y' then 'EXP:' || TrialID else 'EXP:PUBLIC' end
	from i2b2demodata.patient_dimension
	where sourcesystem_cd like TrialID || ':%';
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert data for trial into I2B2DEMODATA patient_trial',rowCount,stepCt,'Done');
	
	--	if secure study, then create bio_experiment record if needed and insert to search_secured_object
	
	select count(*) into pExists
	from searchapp.search_secure_object sso
	where bio_data_unique_id = 'EXP:' || TrialId;
	
	if pExists = 0 then
		--	if securedStudy = Y, add trial to searchapp.search_secured_object
		if securedStudy = 'Y' then
			select count(*) into pExists
			from biomart.bio_experiment
			where accession = TrialId;
			
			if pExists = 0 then
				insert into biomart.bio_experiment
				(title, accession, etl_id)
				select 'Metadata not available'
					  ,TrialId
					  ,'METADATA:' || TrialId;
				rowCount := ROW_COUNT;
				stepCt := stepCt + 1;
				call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert trial/study into biomart.bio_experiment',rowCount,stepCt,'Done');
			end if;
			
			select bio_experiment_id into v_bio_experiment_id
			from biomart.bio_experiment
			where accession = TrialId;
			
			insert into searchapp.search_secure_object
			(bio_data_id
			,display_name
			,data_type
			,bio_data_unique_id
			)
			select v_bio_experiment_id
				  ,tm_cz.parse_nth_value(md.c_fullname,2,bslash) || ' - ' || md.c_name as display_name
				  ,'EXPERIMENT' as data_type
				  ,'EXP:' || TrialId as bio_data_unique_id
			from i2b2metadata.i2b2 md
			where md.sourcesystem_cd = TrialId
			  and md.c_hlevel = 
				 (select min(x.c_hlevel) from i2b2metadata.i2b2 x
				  where x.sourcesystem_cd = TrialId)
			  and not exists
				 (select 1 from searchapp.search_secure_object so
				  where v_bio_experiment_id = so.bio_data_id);
			rowCount := ROW_COUNT;
			stepCt := stepCt + 1;
			-- call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Inserted trial/study into SEARCHAPP search_secure_object',rowCount,stepCt,'Done');
		end if;
	else
		--	if securedStudy = N, delete entry from searchapp.search_secure_object
		if securedStudy = 'N' then
			select search_secure_object_id into v_sso_id
			from searchapp.search_secure_object
			where bio_data_unique_id = 'EXP:' || TrialId;
		
			--	delete security for object
		
			delete from searchapp.search_auth_sec_object_access
			where secure_object_id = v_sso_id;
			rowCount := ROW_COUNT;
			stepCt := stepCt + 1;
			call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Removed study secure object id from search_auth_sec_object_access',1,stepCt,'Done');
		
			--	delete security links between users and study
		
			delete from searchapp.search_auth_user_sec_access
			where search_secure_object_id = v_sso_id;
			rowCount := ROW_COUNT;
			stepCt := stepCt + 1;
			-- call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Removed study secure object id from search_auth_user_sec_access',1,stepCt,'Done');

			--	delete search_secure_object
			
			delete from searchapp.search_secure_object
			where bio_data_unique_id = 'EXP:' || TrialId;
			rowCount := ROW_COUNT;
			stepCt := stepCt + 1;
			call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Deleted trial/study from SEARCHAPP search_secure_object',rowCount,stepCt,'Done');
		end if;		
	end if;
     
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

