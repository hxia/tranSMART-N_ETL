CREATE OR REPLACE PROCEDURE TM_CZ.I2B2_ADD_ROOT_NODE(CHARACTER VARYING(2000), BIGINT)
RETURNS CHARACTER VARYING(ANY)
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
		root_node		alias for $1;
		currentJobID	alias for $2;
		
	--Audit variables
	newJobFlag 	int4;
	databaseName 	varchar(100);
	procedureName varchar(100);
	jobID 		numeric(18,0);
	stepCt 		numeric(18,0);
	rowCount	numeric(18,0);

	rootNode	varchar(200);
	rootPath	varchar(200);
	bslash		char(1);
	etlDate		timestamp;
	v_sqlerrm	varchar(1000);
	
Begin
	rootNode := root_node;
	bslash := '\\';
	rootPath := bslash || rootNode || bslash;
	select now() into etlDate;

    stepCt := 0;
	rowCount := 0;
	
	--Set Audit Parameters
	newJobFlag := 0; -- False (Default)
	jobID := currentJobID;

	databaseName := 'TM_CZ';
	procedureName := 'I2B2_ADD_ROOT_NODE';

	--Audit JOB Initialization
	--If Job ID does not exist, then this is a single procedure run and we need to create it
	IF(jobID IS NULL or jobID < 1)
	THEN
		newJobFlag := 1; -- True
		jobId := tm_cz.czx_start_audit (procedureName, databaseName);
	END IF;
	
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Start ' || procedureName,0,stepCt,'Done');
	
	insert into i2b2metadata.table_access
	select rootNode as c_table_cd
		  ,'i2b2' as c_table_name
		  ,'N' as protected_access
		  ,0 as c_hlevel
		  ,rootPath as c_fullname
		  ,rootNode as c_name
		  ,'N' as c_synonym_cd
		  ,'CA' as c_visualattributes
		  ,null as c_totalnum
		  ,null as c_basecode
		  ,null as c_metadataxml
		  ,'concept_cd' as c_facttablecolumn
		  ,'concept_dimension' as c_dimtablename
		  ,'concept_path' as c_columnname
		  ,'T' as c_columndatatype
		  ,'LIKE' as c_operator
		  ,rootPath as c_dimcode
		  ,null as c_comment
		  ,rootPath as c_tooltip
		  ,etlDate as c_entry_date
		  ,null as c_change_date
		  ,null as c_status_cd
		  ,null as valuetype_cd
	where not exists
		(select 1 from i2b2metadata.table_access x
		 where x.c_table_cd = rootNode);
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert to table_access',rowCount,stepCt,'Done');

	--	insert root_node into i2b2
	
	insert into i2b2metadata.i2b2
	(c_hlevel
	,c_fullname
	,c_name
	,c_synonym_cd
	,c_visualattributes
	,c_totalnum
	,c_basecode
	,c_metadataxml
	,c_facttablecolumn
	,c_tablename
	,c_columnname
	,c_columndatatype
	,c_operator
	,c_dimcode
	,c_comment
	,c_tooltip
	,update_date
	,download_date
	,import_date
	,sourcesystem_cd
	,valuetype_cd
	,m_applied_path
	,i2b2_id
	)
	select 0 as c_hlevel
		  ,rootPath as c_fullname
		  ,rootNode as c_name
		  ,'N' as c_synonym_cd
		  ,'CA' as c_visualattributes
		  ,null as c_totalnum
		  ,null as c_basecode
		  ,null as c_metadataxml
		  ,'concept_cd' as c_facttablecolumn
		  ,'concept_dimension' as c_tablename
		  ,'concept_path' as c_columnname
		  ,'T' as c_columndatatype
		  ,'LIKE' as c_operator
		  ,rootPath as c_dimcode
		  ,null as c_comment
		  ,rootPath as c_tooltip
		  ,etlDate as update_date
		  ,null as download_date
		  ,etlDate as import_date
		  ,null as sourcesystem_cd
		  ,null as valuetype_cd
		  ,'@'
		  ,next value for i2b2metadata.sq_i2b2_id
	where not exists
		 (select 1 from i2b2metadata.i2b2 x
		  where x.c_name = rootNode);		
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert root_node ' || rootNode || ' to i2b2',rowCount,stepCt,'Done');
			
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'End ' || procedureName,0,stepCt,'Done');

	--Cleanup OVERALL JOB if this proc is being run standalone
	IF newJobFlag = 1
	THEN
		call tm_cz.czx_end_audit (jobID, 'SUCCESS');
	END IF;

	EXCEPTION
	WHEN OTHERS THEN
		v_sqlerrm := substr(SQLERRM, 1, 1000);
		raise notice 'error: %', SQLERRM;
		--Handle errors.
		call tm_cz.czx_error_handler (jobID, procedureName);
		--End Proc
		call tm_cz.czx_end_audit (jobID, 'FAIL');
	
END;
END_PROC;

