CREATE OR REPLACE PROCEDURE TM_CZ.I2B2_ADD_NODE(CHARACTER VARYING(50), CHARACTER VARYING(2000), CHARACTER VARYING(500), BIGINT)
RETURNS int4
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
	TrialID 		alias for $1;
	input_path 		alias for $2;
	path_name		alias for $3;
	currentJobID 	alias for $4;
 
	root_node		varchar(2000);
	root_level	int4;
	etlDate		timestamp;
	bslash		char(1);
	v_concept_id	bigint;
	pExists		int4;
	v_sqlerrm	varchar(1000);
  
  
  --Audit variables
  newJobFlag int4;
  databaseName VARCHAR(100);
  procedureName VARCHAR(100);
  jobID numeric(18,0);
  stepCt numeric(18,0);
  rowCount		numeric(18,0);
  
BEGIN

	stepCt := 0;
	rowCount := 0;
	select now() into etlDate;
	bslash := '\\';
	
	--Set Audit Parameters
	newJobFlag := 0; -- False (Default)
	jobID := currentJobID;

	databaseName := 'TM_CZ';
	procedureName := 'I2B2_ADD_NODE';
 
	root_node := tm_cz.parse_nth_value(input_path, 2, bslash);

	select c_hlevel into root_level
	from i2b2metadata.table_access
	where c_name = root_node;

	--Audit JOB Initialization
	--If Job ID does not exist, then this is a single procedure run and we need to create it
	IF(jobID IS NULL or jobID < 1)
	THEN
		newJobFlag := 1; -- True
		jobId := tm_cz.czx_start_audit (procedureName, databaseName);
	END IF;
  
	if input_path = ''  or input_path = '%' or path_name = ''
	then 
		stepCt := stepCt + 1;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Missing path or name - path:' || input_path || ' name: ' || path_name,rowCount,stepCt,'Done');
	else
	
		select count(*) into pExists
		from i2b2demodata.concept_dimension
		where input_path = concept_path;
		
		if pexists = 0 then
			select next value for i2b2demodata.sq_concept_cd into v_concept_id;
			--CONCEPT DIMENSION
			insert into i2b2demodata.concept_dimension
			(concept_cd
			,concept_path
			,name_char
			,update_date
			,download_date
			,import_date
			,sourcesystem_cd
			)
			select v_concept_id
				  ,input_path
				  ,path_name
				  ,etlDate
				  ,etlDate
				  ,etlDate
				  ,TrialID;
			rowCount := ROW_COUNT;
			stepCt := stepCt + 1;
			call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Inserted concept for path into I2B2DEMODATA concept_dimension',rowCount,stepCt,'Done');
		end if;
	
		select count(*) into pExists
		from i2b2metadata.i2b2
		where input_path = c_fullname;
		
		if pExists = 0 then 
			--I2B2
			insert into i2b2metadata.i2b2
			(c_hlevel
			,c_fullname
			,c_name
			,c_visualattributes
			,c_synonym_cd
			,c_facttablecolumn
			,c_tablename
			,c_columnname
			,c_dimcode
			,c_tooltip
			,update_date
			,download_date
			,import_date
			,sourcesystem_cd
			,c_basecode
			,c_operator
			,c_columndatatype
			,c_comment
			,m_applied_path
			,i2b2_id
			)
			select (length(concept_path) - coalesce(length(replace(concept_path, bslash, '')),0)) / length(bslash) - 2 + root_level
				  ,concept_path
				  ,name_char
				  ,'FA'
				  ,'N'
				  ,'CONCEPT_CD'
				  ,'CONCEPT_DIMENSION'
				  ,'CONCEPT_PATH'
				  ,concept_path
				  ,concept_path
				  ,etldate
				  ,etldate
				  ,etldate
				  ,sourcesystem_cd
				  ,concept_cd
				  ,'LIKE'
				  ,'T'
				  ,case when TrialID is null then null else 'trial:' || TrialID end
				  ,'@'
				  ,next value for i2b2metadata.sq_i2b2_id
			from i2b2demodata.concept_dimension
			where concept_path = input_path;
			rowCount := ROW_COUNT;
			stepCt := stepCt + 1;
			call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Inserted path into I2B2METADATA i2b2',rowCount,stepCt,'Done');
		end if;
	end if;
	
      ---Cleanup OVERALL JOB if this proc is being run standalone
	if newjobflag = 1
	then
		call tm_cz.czx_end_audit (jobID, 'SUCCESS');
	end if;
	
	return 0;

	exception
	when others then
		v_sqlerrm := substr(SQLERRM,1,1000);
		raise notice 'error: %', v_sqlerrm;
		--Handle errors.
		call tm_cz.czx_error_handler (jobID, procedureName,v_sqlerrm);
		--End Proc
		call tm_cz.czx_end_audit (jobID, 'FAIL');
		return 16;

END;
END_PROC;

