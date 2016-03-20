CREATE OR REPLACE PROCEDURE TM_CZ.I2B2_MOVE_STUDY (CHARACTER VARYING(ANY), CHARACTER VARYING(ANY), INTEGER)
RETURNS int4
LANGUAGE NZPLSQL AS
BEGIN_PROC
DECLARE
	trial_id ALIAS FOR $1;
	topNode ALIAS FOR $2;
	currentJobID ALIAS FOR $3;
-- BEGIN

  root_node			varchar(2000);
  root_level		int;
  topLevel			int;
  TrialId			varchar(100);
  old_Path			varchar(2000);
  newPath			varchar(2000);
  new_study_name	varchar(200);
  old_study_name	varchar(200);
  pExists			int;
  v_sqlerrm			varchar(1000);
  
  --	new variables
  bslash char(1);
  rowCount	numeric(18,0);
 
  --Audit variables
  --newJobFlag INTEGER(1);
  newJobFlag int4;
  databaseName VARCHAR(100);
  procedureName VARCHAR(100);
  jobID numeric(18,0);    -- replaced number with numeric
  stepCt numeric(18,0);	  -- replaced number with numeric
  
 -- invalid_TrialId		exception;
 -- invalid_topNode		exception;
Begin  
 	TrialId := upper(trial_id);
	stepCt := 0;
	bslash := '\\';   -- new assignment
	
	--Set Audit Parameters
	newJobFlag := 0; -- False (Default)
	jobID := currentJobID;

	databaseName := 'TM_CZ';
	procedureName := 'I2B2_MOVE_STUDY';
  	
	
	--Audit JOB Initialization
	--If Job ID does not exist, then this is a single procedure run and we need to create it
	IF(jobID IS NULL or jobID < 1)
	THEN
		newJobFlag := 1; -- True
		jobId := tm_cz.czx_start_audit (procedureName, databaseName);
	END IF;

	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Start '||procedureName,0,stepCt,'Done'); 

	--	check if study exists
	
	select count(*) into pExists
	from i2b2metadata.i2b2
	where sourcesystem_cd = TrialId;
	
	if pExists = 0 then
		-- raise invalid_TrialId;  exceptions not supported in Netezza
		stepCt := stepCt + 1;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Trial Id '||trial_id||' does not exist',0,stepCt,'Done');	
		call tm_cz.czx_error_handler (jobID, procedureName,'Application raised error');
		call tm_cz.czx_end_audit (jobID, 'FAIL');
		return 16;
	end if;
	
	--	get current top node for study
	
	select min(c_fullname) into old_path
	from i2b2metadata.i2b2
	where sourcesystem_cd = TrialId;
	
	--	get current study name for study
	
	select c_name into old_study_name
	from i2b2metadata.i2b2
	where c_fullname = old_path;
	
	--	check that topNode is not null or %
	
	if coalesce(topNode,'') = '' or topNode = '%' then
		-- raise invalid_topNode;  exception not supported in Netezza
		stepCt := stepCt + 1;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Path specified as topNode must contain at least 2 nodes',0,stepCt,'Done');	
		call tm_cz.czx_error_handler (jobID, procedureName,'Application raised error');
		call tm_cz.czx_end_audit (jobID, 'FAIL');
		return 16;
	end if;
	
	newPath := REGEXP_REPLACE(bslash || topNode || bslash,'(\\){2,}', bslash);
	topLevel := length(newPath)-length(replace(newPath,bslash,''));
	--select length(newPath)-length(replace(newPath,'\','')) into topLevel; -- from dual;
	
	if topLevel < 3 then
		-- raise invalid_topNode;  exception not supported  by Netezza
		stepCt := stepCt + 1;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Path specified as topNode must contain at least 2 nodes',0,stepCt,'Done');	
		call tm_cz.czx_error_handler (jobID, procedureName,'Application raised error');
		call tm_cz.czx_end_audit (jobID, 'FAIL');
		return 16;
	end if;
	
	--	get root_node of new path
	
	root_node := tm_cz.parse_nth_value(newPath, 2, bslash);
	--select parse_nth_value(newPath, 2, '\') into root_node; -- from dual;
	
	select count(*) into pExists
	from i2b2metadata.table_access
	where c_name = root_node;
		
	--	add root_node if it doesn't exist
	
	if pExists = 0 then
		call tm_cz.i2b2_add_root_node(root_node,jobId);
	end if;
		
	select c_hlevel into root_level
	from i2b2metadata.table_access
	where c_name = root_node;
		
	--	get study_name from new path, doesn't have to be the same as the existing study name
	
	new_study_name := tm_cz.parse_nth_value(newPath, topLevel, bslash);
	--select parse_nth_value(newPath, topLevel, '\') into new_study_name; -- from dual;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'study_name: ' || new_study_name,0,stepCt,'Done');
	
	--	create backup for concept_dimension and i2b2
	
	insert into i2b2demodata.concept_dimension
	(concept_path
	,concept_cd
	,name_char
	,concept_blob
	,update_date
	,download_date
	,import_date
	,sourcesystem_cd
	,upload_id
	)
	select concept_path
		  ,concept_cd
		  ,name_char
		  ,concept_blob
		  ,update_date
		  ,download_date
		  ,import_date
		  ,'BKP:' || TrialId as sourcesystem_cd
		  ,upload_id
	from i2b2demodata.concept_dimension
	where sourcesystem_cd = TrialId;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Backup concept_dimension',rowCount,stepCt,'Done'); 
	
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
    ,m_applied_path
    ,update_date
    ,download_date
    ,import_date
    ,sourcesystem_cd
    ,valuetype_cd
    ,m_exclusion_cd
    ,c_path
    ,c_symbol
	,i2b2_id
	)
	select  c_hlevel
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
		   ,replace(c_fullname, old_path, newPath)
		   ,c_comment
		   ,replace(c_fullname, old_path, newPath)
		   ,m_applied_path
		   ,update_date
		   ,download_date
		   ,import_date
		   ,'BKP:' || TrialId as sourcesystem_cd
		   ,valuetype_cd
		   ,m_exclusion_cd
		   ,c_path
		   ,c_symbol
		   ,i2b2_id
	from i2b2metadata.i2b2
	where sourcesystem_cd = TrialId;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Backup i2b2',rowCount,stepCt,'Done'); 
		
    --CONCEPT DIMENSION
	--	insert records for new path
	
	insert into i2b2demodata.concept_dimension
	(concept_path
	,concept_cd
	,name_char
	,concept_blob
	,update_date
	,download_date
	,import_date
	,sourcesystem_cd
	,upload_id
	)
	select replace(concept_path, old_path, newPath) as concept_path
		  ,concept_cd
		  ,name_char
		  ,concept_blob
		  ,update_date
		  ,download_date
		  ,import_date
		  ,'TMP:' || TrialId as sourcesystem_cd
		  ,upload_id
	from i2b2demodata.concept_dimension
	where sourcesystem_cd = TrialId;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Add new path to concept_dimension',rowCount,stepCt,'Done'); 
	
	--update i2b2demodata.concept_dimension
	--set CONCEPT_PATH = replace(concept_path, old_path, newPath)
	--where concept_path like old_path || '%';
	--rowCount := ROW_COUNT;
	--stepCt := stepCt + 1;
	--call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Update concept_dimension with new path',rowCount,stepCt,'Done'); 
	-- COMMIT;   commit not supported
    
	--I2B2
	
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
    ,m_applied_path
    ,update_date
    ,download_date
    ,import_date
    ,sourcesystem_cd
    ,valuetype_cd
    ,m_exclusion_cd
    ,c_path
    ,c_symbol
	,i2b2_id
	)
	select  (length(replace(c_fullname, old_path, newPath)) - coalesce(length(replace(replace(c_fullname, old_path, newPath), bslash,'')),0)) / length(bslash) - 2 + root_level as c_hlevel
		   ,replace(c_fullname, old_path, newPath) as c_fullname
		   ,replace(substr(replace(c_fullname, old_path, newPath),instr(replace(c_fullname, old_path, newPath),bslash,-2)+1),bslash,'') as c_name
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
		   ,replace(c_fullname, old_path, newPath)
		   ,c_comment
		   ,replace(c_fullname, old_path, newPath)
		   ,m_applied_path
		   ,update_date
		   ,download_date
		   ,import_date
		   ,'TMP:' || TrialId as sourcesystem_cd
		   ,valuetype_cd
		   ,m_exclusion_cd
		   ,c_path
		   ,c_symbol
		   ,i2b2_id
	from i2b2metadata.i2b2
	where sourcesystem_cd = TrialId;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Add new path to i2b2',rowCount,stepCt,'Done'); 

	--update i2b2
	--set c_fullname = replace(c_fullname, old_path, newPath)
	--	,c_dimcode = replace(c_fullname, old_path, newPath)
	--	,c_tooltip = replace(c_fullname, old_path, newPath)
	--	,c_hlevel =  (length(replace(c_fullname, old_path, newPath)) - coalesce(length(replace(replace(c_fullname, old_path, newPath), bslash, '')),0)) / length(bslash) - 2 + root_level
	--	,c_name = replace(substr(replace(c_fullname, old_path, newPath),instr(replace(c_fullname, old_path, newPath),bslash,-2)+1),bslash,'')
	--	,c_name = parse_nth_value(replace(c_fullname, old_path, newPath),(length(replace(c_fullname, old_path, newPath))-length(replace(replace(c_fullname, old_path, newPath),bslash,''))),bs;asj) 
	--where c_fullname like old_path || '%';
	--rowCount := ROW_COUNT;
	--stepCt := stepCt + 1;
	--call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Update i2b2 with new path',rowCount,stepCt,'Done'); 
	-- COMMIT;  not supported
		
	--	concept_counts
/*		
	update i2b2demodata.concept_counts
	set concept_path = replace(concept_path, old_path, newPath)
	   ,parent_concept_path = replace(parent_concept_path, old_path, newPath)
	where concept_path like old_path || '%';
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Update concept_counts pass 1',rowCount,stepCt,'Done'); 
	-- COMMIT;  not supported
	
	--	update parent_concept_path for new_path (replace doesn't work)
	
	update i2b2demodata.concept_counts 
	set parent_concept_path=ltrim(SUBSTR(concept_path, 1,instr(concept_path, bslash,-1,2)))
	where concept_path = newPath;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Update concept_counts pass 2',rowCount,stepCt,'Done'); 
	-- COMMIT; not supported
*/
	
	--	delete original data from concept_dimension
	
	delete from i2b2demodata.concept_dimension
	where sourcesystem_cd = Trialid;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete old path in concept_dimension',rowCount,stepCt,'Done');
	
	--	rename sourcesystem_cd on concept_dimension 
	
	update i2b2demodata.concept_dimension
	set sourcesystem_cd=Trialid
	where sourcesystem_cd = 'TMP:' || TrialId;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Update sourcesystem_cd in new_path for concept_dimension',rowCount,stepCt,'Done');
	
	--	delete original data from i2b2
	
	delete from i2b2metadata.i2b2
	where sourcesystem_cd = Trialid;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete old path in i2b2',rowCount,stepCt,'Done');
	
	--	rename sourcesystem_cd on i2b2
	
	update i2b2metadata.i2b2
	set sourcesystem_cd=Trialid
	where sourcesystem_cd = 'TMP:' || TrialId;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Update sourcesystem_cd in new_path for i2b2',rowCount,stepCt,'Done');
		
	--	fill in any upper levels
	
	call tm_cz.i2b2_fill_in_tree(null, newPath, jobID);
	
	--	create new concept_counts
	
	call tm_cz.i2b2_create_concept_counts(newPath, jobID);
	
	--	delete old concept_counts
	
	delete from i2b2demodata.concept_counts
	where concept_path like old_path || '%' escape '';
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete concept_counts for old path',rowCount,stepCt,'Done');
	
	--	update modifier_dimension if new_study_name not equal old_study_name
	
	if new_study_name != old_study_name then
		insert into i2b2demodata.modifier_dimension
		(modifier_path
		,modifier_cd
		,name_char
		,modifier_level
		,modifier_node_type
		,sourcesystem_cd
		)
		select bslash || 'Study' || bslash || new_study_name || bslash
		,'STUDY:' || TrialId
		,new_study_name
		,1
		,'L'
		,TrialId;
		rowCount := ROW_COUNT;
		stepCt := stepCt + 1;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Add new study name in modifier dimension',rowCount,stepCt,'Done');
		
		delete from i2b2demodata.modifier_dimension
		where modifier_path = bslash || 'Study' || bslash || old_study_name || bslash;
		rowCount := ROW_COUNT;
		stepCt := stepCt + 1;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete old study name from modifier dimension',rowCount,stepCt,'Done');

		--update i2b2demodata.modifier_dimension
		--set modifier_path=bslash || 'Study' || bslash || new_study_name || bslash
		--   ,name_char=new_study_name
		--where modifier_cd = 'STUDY:' || TrialId;
		--stepCt := stepCt + 1;
		--call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Update study name in modifier_dimension',rowCount,stepCt,'Done'); 
		--COMMIT;   commit not supported
	end if;	
	
	call tm_cz.i2b2_load_security_data(jobId);
	
	--	cleanup BKP data
	
	delete from i2b2metadata.i2b2
	where sourcesystem_cd = 'BKP:' || Trialid;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete backup i2b2 for old path',rowCount,stepCt,'Done');
	
	delete from i2b2demodata.concept_dimension
	where sourcesystem_cd = 'BKP:' || Trialid;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete backup concept_dimension for old path',rowCount,stepCt,'Done');
	
	
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

