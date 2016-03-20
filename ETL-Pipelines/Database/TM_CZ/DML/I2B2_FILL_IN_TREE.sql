CREATE OR REPLACE PROCEDURE TM_CZ.I2B2_FILL_IN_TREE(CHARACTER VARYING(50), CHARACTER VARYING(500), BIGINT)
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
	trial_id alias for $1;
	input_path alias for $2;
	currentJobID alias for $3;
 
	TrialID varchar(100);
  
    --Audit variables
	newJobFlag int4;
	databaseName VARCHAR(100);
	procedureName VARCHAR(100);
	jobID numeric(18,0);
	stepCt numeric(18,0);
	rowCount		numeric(18,0);
  
	auditText 	varchar(4000);
	etlDate		timestamp;
	root_level	int4;
	curr_node	varchar(700);
	node_name	varchar(700);
	topNode		varchar(2000);
	v_count		int8;
	bslash		char(1);
	v_concept_id	bigint;
	v_sqlerrm		varchar(1000);
	
	r_cNodes	record;
  
BEGIN
	TrialID := upper(trial_id);
  
    stepCt := 0;
	select now() into etlDate;
	bslash := '\\';
	
	--Set Audit Parameters
	newJobFlag := 0; -- False (Default)
	jobID := currentJobID;

	databaseName := 'TM_CZ';
	procedureName := 'I2B2_FILL_IN_TREE';

	--Audit JOB Initialization
	--If Job ID does not exist, then this is a single procedure run and we need to create it
	IF(jobID IS NULL or jobID < 1)
	THEN
		newJobFlag := 1; -- True
		jobId := tm_cz.czx_start_audit (procedureName, databaseName);
	END IF;
  
  	curr_node := tm_cz.parse_nth_value(input_path, 2, bslash);
	
	select c_hlevel into root_level
	from i2b2metadata.table_access
	where c_name = curr_node;
	
	if TrialId is not null then
		select min(c_fullname) from i2b2metadata.i2b2 into topNode where sourcesystem_cd = Trialid;
	end if;
	
	--start node with the first slash
	
	execute immediate 'truncate table tm_wz.wt_folder_nodes';
 
	--Iterate through each node
	FOR r_cNodes in	
		select distinct substr(c_fullname, 1,instr(c_fullname,bslash,-2,1)) as c_fullname
		from i2b2metadata.i2b2 
		where c_fullname like input_path || '%' escape ''
		union
		--	add input_path if filling in upper-level nodes only
		select input_path as c_fullname
	loop
		for loop_counter in 1 .. (length(r_cNodes.c_fullname) - coalesce(length(replace(r_cNodes.c_fullname, bslash,'')),0)) / length(bslash)
		LOOP
			--Determine Node:
			curr_node := substr(r_cNodes.c_fullname,1,instr(r_cNodes.c_fullname,bslash,-1,loop_counter));	
			node_name := tm_cz.parse_nth_value(curr_node,length(curr_node)-length(replace(curr_node,bslash,'')),bslash);
			if curr_node is not null and curr_node != bslash then
				insert into tm_wz.wt_folder_nodes
				(folder_path,folder_name)
				select curr_node,node_name
				where not exists
					 (select 1 from tm_wz.wt_folder_nodes
					  where folder_path = curr_node);
			end if;
		end loop;
	end loop;	
			
	--	bulk insert concept_dimension records
	
	insert into i2b2demodata.concept_dimension
	(concept_cd
	,concept_path
	,name_char
	,update_date
	,download_date
	,import_date
	,sourcesystem_cd)
	Select next value for i2b2demodata.sq_concept_cd
	      ,folder_path
		  ,folder_name
		  ,etlDate
		  ,etlDate
		  ,etlDate
		  ,case when folder_path < topNode then null else TrialID end
	from (select distinct folder_path, folder_name from tm_wz.wt_folder_nodes
		  where not exists
			   (select 1 from i2b2demodata.concept_dimension cd where folder_path = cd.concept_path)) y ;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Inserted concept for path into I2B2DEMODATA concept_dimension',rowCount,stepCt,'Done');
    
	--	bulk insert the i2b2 records

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
	,i2b2_id)
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
		  ,etlDate
		  ,etlDate
		  ,etlDate
		  ,sourcesystem_cd
		  ,concept_cd
		  ,'LIKE'
		  ,'T'
		  ,case when concept_path < topNode then null else 'trial:' || TrialID end
		  ,'@'
		  ,next value for i2b2metadata.sq_i2b2_id
    from i2b2demodata.concept_dimension cd
    where cd.concept_path in (select distinct folder_path from tm_wz.wt_folder_nodes)
	  and not exists
		  (select 1 from i2b2metadata.i2b2 x
		   where cd.concept_path = x.c_fullname);
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Inserted path into I2B2METADATA i2b2',rowCount,stepCt,'Done');

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

