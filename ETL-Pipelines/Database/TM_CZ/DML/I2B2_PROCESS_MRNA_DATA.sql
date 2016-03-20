CREATE OR REPLACE PROCEDURE TM_CZ.I2B2_PROCESS_MRNA_DATA(CHARACTER VARYING(50), CHARACTER VARYING(500), CHARACTER VARYING(10), CHARACTER VARYING(50), NUMERIC(4,0), CHARACTER VARYING(50), BIGINT)
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

	trial_id alias for $1;
	top_node alias for $2;		
	data_type alias for $3;	
		--	R = raw data, do zscore calc, T = transformed data, load raw values as zscore,
		--	L = log intensity data, skip log step in zscore calc
	v_source_cd alias for $4;
	log_base alias for $5;		--	log base value for conversion back to raw
	secure_study alias for $6;	--	security setting if new patients added to patient_dimension
	currentJobID alias for $7; 	
	
--	***  NOTE ***
--	The input file columns are mapped to the following table columns.  This is done so that the javascript for the advanced workflows
--	selects the correct data for the dropdowns.

--		tissue_type	=>	sample_type
--		attribute_1	=>	tissue_type
--		atrribute_2	=>	timepoint	

	TrialID		character varying(100);
	RootNode	character varying(2000);
	root_level	int4;
	topNode		character varying(2000);
	topLevel	int4;
	tPath		character varying(2000);
	study_name	character varying(100);
	sourceCd	character varying(50);
	secureStudy	character varying(1);

	dataType	character varying(10);
	sqlText		character varying(1000);
	tText		character varying(1000);
	gplTitle	character varying(1000);
	pExists		int4;
	sampleCt	numeric;
	idxExists 	int4;
	logBase		numeric(8,0);
	pCount		int4;
	sCount		int4;
	tablespaceName	character varying(200);
	v_bio_experiment_id	numeric(18,0);
	runDate		timestamp;
	bslash		char(1);
	v_sqlerrm	varchar(1000);
	v_sourcesystem_ct	int4;
	v_topNode_ct		int4;
	
	--	records
	r_Nodes	record;
  
    --Audit variables
	newJobFlag int4;
	databaseName VARCHAR(100);
	procedureName VARCHAR(100);
	jobID bigint;
	stepCt numeric(18,0);
	rowCount		numeric(18,0);

BEGIN
	TrialID := upper(trial_id);
	secureStudy := upper(coalesce(secure_study,'N'));
	bslash := '\\';
	select now() into runDate;
	
	if (secureStudy not in ('Y','N') ) then
		secureStudy := 'Y';
	end if;
	
	topNode := REGEXP_REPLACE(bslash || top_node || bslash,'(\\){2,}', bslash);	
	topLevel := length(topNode)-length(replace(topNode,bslash,''));
	
	if data_type is null then
		dataType := 'R';
	else
		if data_type in ('R','T','L') then
			dataType := data_type;
		else
			dataType := 'R';
		end if;
	end if;
	
	logBase := log_base;
	sourceCd := upper(coalesce(v_source_cd,'STD'));

	--Set Audit Parameters
	newJobFlag := 0; -- False (Default)
	jobID := currentJobID;

	databaseName := 'TM_CZ';
	procedureName := 'I2B2_PROCESS_MRNA_DATA';

	--Audit JOB Initialization
	--If Job ID does not exist, then this is a single procedure run and we need to create it
	IF(jobID IS NULL or jobID < 1)
	THEN
		newJobFlag := 1; -- True
		jobId := tm_cz.czx_start_audit (procedureName, databaseName);
	END IF;
	raise notice 'after start audit';
    	
	stepCt := 0;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Starting i2b2_process_mrna_data',0,stepCt,'Done');
	
	--	check for mismatch between TrialId and topNode for previously loaded data
	
	select count(*) into v_sourcesystem_ct
	from i2b2metadata.i2b2
	where sourcesystem_cd = TrialId;
	
	select count(*) into v_topNode_ct
	from i2b2metadata.i2b2
	where c_fullname = topNode;
	
	if (v_sourcesystem_ct = 0 and v_topNode_ct > 0) or (v_sourcesystem_ct > 0 and v_topNode_ct = 0) then
		stepCt := stepCt + 1;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'TrialId and topNode are mismatched',0,stepCt,'Done');	
		call tm_cz.czx_error_handler (jobID, procedureName,'Application raised error');
		call tm_cz.czx_end_audit (jobID, 'FAIL');
		return 16;
	end if;
	
	if v_sourcesystem_ct > 0 and v_topNode_ct > 0 then
		select count(*) into v_topNode_ct
		from i2b2metadata.i2b2
		where sourcesystem_cd = TrialId
		  and c_fullname = topNode;
		if v_topNode_ct = 0 then
			stepCt := stepCt + 1;
			call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'TrialId and topNode are mismatched',0,stepCt,'Done');	
			call tm_cz.czx_error_handler (jobID, procedureName,'Application raised error');
			call tm_cz.czx_end_audit (jobID, 'FAIL') into rtnCd;
			return 16;
		end if;
	end if;
	
	--	Get count of records in lt_src_mrna_subj_samp_map
	
	select count(*) into sCount
	from tm_lz.lt_src_mrna_subj_samp_map;
	
	--	check if all subject_sample map records have a platform, If not, abort run
	
	select count(*) into pCount
	from tm_lz.lt_src_mrna_subj_samp_map
	where platform is null;
	
	if pCount > 0 then
		call tm_cz.czx_write_audit(jobId,databasename,procedurename,'Platform data missing from one or more subject_sample mapping records',1,stepCt,'ERROR');
		call tm_cz.czx_error_handler(jobid,procedurename,'Application raised error');
		call tm_cz.czx_end_audit (jobId,'FAIL');
		return 16;
	end if;
  
  	--	check if platform exists in de_mrna_annotation .  If not, abort run.
	
	select count(*) into pCount
	from deapp.DE_MRNA_ANNOTATION
	where GPL_ID in (select distinct m.platform from tm_lz.lt_src_mrna_subj_samp_map m);
	
	if pCount = 0 then
		call tm_cz.czx_write_audit(jobId,databasename,procedurename,'Platform not found in deapp.de_mrna_annotation',1,stepCt,'ERROR');
		call tm_cz.czx_ERROR_HANDLER(JOBID,PROCEDURENAME,'Application raised error');
		call tm_cz.czx_end_audit (jobId,'FAIL');
		return 16;
	end if;
	
	select count(*) into pCount
	from deapp.DE_gpl_info
	where platform in (select distinct m.platform from tm_lz.lt_src_mrna_subj_samp_map m);
	
	if pCount = 0 then
		call tm_cz.czx_write_audit(jobId,databasename,procedurename,'Platform not found in deapp.de_gpl_info',1,stepCt,'ERROR');
		call tm_cz.czx_ERROR_HANDLER(JOBID,PROCEDURENAME,'Application raised error');
		call tm_cz.czx_end_audit (jobId,'FAIL');
		return 16;
	end if;
		
	--	check if all subject_sample map records have a tissue_type, If not, abort run
	
	select count(*) into pCount
	from tm_lz.lt_src_mrna_subj_samp_map
	where tissue_type is null;
	
	if pCount > 0 then
		call tm_cz.czx_write_audit(jobId,databasename,procedurename,'Tissue Type data missing from one or more subject_sample mapping records',1,stepCt,'ERROR');
		call tm_cz.czx_error_handler(jobid,procedurename,'Application raised error');
		call tm_cz.czx_END_AUDIT (JOBID,'FAIL');
		return 16;
	end if;
	
	--	check if there are multiple platforms, if yes, then platform must be supplied in lt_src_mrna_data
	
	select count(*) into pCount
	from (select sample_cd
		  from tm_lz.lt_src_mrna_subj_samp_map
		  group by sample_cd
		  having count(distinct platform) > 1) x;
	
	if pCount > 0 then
		call tm_cz.czx_write_audit(jobId,databasename,procedurename,'Multiple platforms for sample_cd in lt_src_mrna_subj_samp_map',1,stepCt,'ERROR');
		call tm_cz.czx_ERROR_HANDLER(JOBID,PROCEDURENAME,'Application raised error');
		call tm_cz.czx_end_audit (jobId,'FAIL');
		return 16;
	end if;
		
	-- Get root_node from topNode
  
	rootNode := replace(substr(topNode,1,instr(topNode,bslash,2)),bslash,'');
	
	select count(*) into pExists
	from i2b2metadata.table_access
	where c_name = rootNode;
	
	if pExists = 0 then
		call tm_cz.i2b2_add_root_node(rootNode, jobId);
	end if;
	
	select c_hlevel into root_level
	from i2b2metadata.i2b2
	where c_name = RootNode;
	
	-- Get study name from topNode
  
	study_name := replace(substr(topNode,instr(topNode,bslash,-2)+1),bslash,'');
	
	--	Add any upper level nodes as needed
	
	tPath := REGEXP_REPLACE(replace(top_node,study_name,''),'(\\){2,}', bslash);
	pCount := length(tPath) - length(replace(tPath,bslash,''));

	if pCount > 2 then
		call tm_cz.i2b2_fill_in_tree(null, tPath, jobId);
	end if;
	
	select count(*) into pExists
	from i2b2metadata.i2b2
	where c_fullname = topNode;
	
	--	add top node for study
	
	if pExists = 0 then
		call tm_cz.i2b2_add_node(TrialId, topNode, study_name, jobId);
	end if;
	
	--	create records in patient_dimension for subject_ids if they do not exist
	--	format of sourcesystem_cd:  trial:[site:]subject_cd
	
	execute immediate 'truncate table tm_wz.wt_subject_info';
	
	insert into tm_wz.wt_subject_info
	(usubjid
	,age_in_years_num
	,sex_cd
	,race_cd
	)
	select distinct regexp_replace(TrialID || ':' || coalesce(s.site_id,'') || ':' || s.subject_id,'(::){1,}', ':')
		  ,0
		  ,'Unknown'
		  ,null
	from tm_lz.lt_src_mrna_subj_samp_map s
	     ,deapp.de_gpl_info g
	 where s.subject_id is not null
	   and upper(s.trial_name) = TrialID
	   and s.source_cd = sourceCD
	   and s.platform = g.platform
	   and upper(g.marker_type) = 'GENE EXPRESSION'
	   and not exists
		  (select 1 from i2b2demodata.patient_dimension x
		   where x.sourcesystem_cd = 
			 regexp_replace(TrialID || ':' || coalesce(s.site_id,'') || ':' || s.subject_id,'(::){1,}', ':'));

	insert into i2b2demodata.patient_dimension
    ( patient_num,
      sex_cd,
      age_in_years_num,
      race_cd,
      update_date,
      download_date,
      import_date,
      sourcesystem_cd
    )
    select next value for i2b2demodata.sq_patient_num
		  ,sex_cd
		  ,age_in_years_num
		  ,race_cd
		  ,runDate
		  ,runDate
		  ,runDate
		  ,usubjid
	from tm_wz.wt_subject_info;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert subjects to patient_dimension',rowCount,stepCt,'Done');
	
	call tm_cz.i2b2_create_security_for_trial(TrialId, secureStudy, jobID);

	--	Delete existing observation_fact data, will be repopulated
	
	delete from i2b2demodata.observation_fact obf
	where obf.concept_cd in
		 (select distinct x.concept_code
		  from deapp.de_subject_sample_mapping x
		  where x.trial_name = TrialId
		    and coalesce(x.source_cd,'STD') = sourceCD
		    and x.platform = 'MRNA_AFFYMETRIX');
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete data from observation_fact',rowCount,stepCt,'Done');
	
	--	delete any existing data from de_subject_microarray_data
	
	delete from deapp.de_subject_microarray_data
	where trial_name = TrialId
	  and assay_id in 
		  (select distinct x.assay_id
		   from deapp.de_subject_sample_mapping x
		   where x.trial_name = TrialId
		     and coalesce(x.source_cd,'STD') = sourceCD
		     and x.platform = 'MRNA_AFFYMETRIX');
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete data from de_subject_microarray_data',ROW_COUNT,stepCt,'Done');

	--	truncate tmp node table

	execute immediate 'truncate table tm_wz.wt_mrna_nodes';
	
	--	load temp table with leaf node path, use temp table with distinct sample_type, ATTR2, platform, and title   this was faster than doing subselect
	--	from wt_subject_mrna_data

	execute immediate 'truncate table tm_wz.wt_mrna_node_values';
	
	insert into tm_wz.wt_mrna_node_values
	(category_cd
	,platform
	,tissue_type
	,attribute_1
	,attribute_2
	,title
	)
	select a.category_cd
		  ,coalesce(a.platform,'GPL570')
		  ,coalesce(a.tissue_type,'Unspecified Tissue Type')
		  ,a.attribute_1
		  ,a.attribute_2
		  ,min(g.title)
    from tm_lz.lt_src_mrna_subj_samp_map a
	    ,deapp.de_gpl_info g 
	where a.trial_name = TrialID
	  and coalesce(a.platform,'GPL570') = g.platform
	  and coalesce(a.source_cd,'STD') = sourceCD
	  and a.platform = g.platform
	  and upper(g.marker_type) = 'GENE EXPRESSION'
	  group by a.category_cd
		  ,coalesce(a.platform,'GPL570')
		  ,coalesce(a.tissue_type,'Unspecified Tissue Type')
		  ,a.attribute_1
		  ,a.attribute_2;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert node values into DEAPP wt_mrna_node_values',rowCount,stepCt,'Done');

	insert into tm_wz.wt_mrna_nodes
	(leaf_node
	,category_cd
	,platform
	,tissue_type
	,attribute_1
    ,attribute_2
	,node_type
	,orig_category_cd
	)
	select distinct substr(topNode || regexp_replace(replace(replace(replace(replace(replace(replace(category_cd,'+',bslash),'PLATFORM',title),'ATTR1',coalesce(attribute_1,'')),'ATTR2',coalesce(attribute_2,'')),'TISSUETYPE',coalesce(tissue_type,'')),'_',' ') || bslash,'(\\){2,}', bslash),1,2000)
		  ,category_cd
		  ,platform as platform
		  ,tissue_type
		  ,attribute_1 as attribute_1
          ,attribute_2 as attribute_2
		  ,'LEAF'
		  ,category_cd
	from  tm_wz.wt_mrna_node_values;  
	rowCount := ROW_COUNT;
    stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Create leaf nodes in DEAPP tmp_mrna_nodes',rowCount,stepCt,'Done');
	raise notice 'after LEAF';
	
	--	insert for platform node so platform concept can be populated
	
	insert into tm_wz.wt_mrna_nodes
	(leaf_node
	,category_cd
	,platform
	,tissue_type
	,attribute_1
    ,attribute_2
	,node_type
	,orig_category_cd
	)
	select distinct substr(topNode || regexp_replace(replace(replace(replace(replace(replace(
	       substr(replace(category_cd,'+',bslash),1,instr(category_cd,'PLATFORM')+8),'PLATFORM',title),'ATTR1',coalesce(attribute_1,'')),'ATTR2',coalesce(attribute_2,'')),'TISSUETYPE',coalesce(tissue_type,'')),'_',' ') || bslash,
		   '(\\){2,}', bslash),1,2000)
		  ,substr(category_cd,1,instr(category_cd,'PLATFORM')+8)
		  ,platform as platform
		  ,case when instr(substr(category_cd,1,instr(category_cd,'PLATFORM')+8),'TISSUETYPE') > 1 then tissue_type else null end as tissue_type
		  ,case when instr(substr(category_cd,1,instr(category_cd,'PLATFORM')+8),'ATTR1') > 1 then attribute_1 else null end as attribute_1
          ,case when instr(substr(category_cd,1,instr(category_cd,'PLATFORM')+8),'ATTR2') > 1 then attribute_2 else null end as attribute_2
		  ,'PLATFORM'
		  ,category_cd
	from  tm_wz.wt_mrna_node_values
	where category_cd like '%PLATFORM%' escape ''; 
	rowCount := ROW_COUNT;
    stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Create platform nodes in wt_mrna_nodes',rowCount,stepCt,'Done');
	raise notice 'after platform';
	
	--	insert for ATTR1 node so ATTR1 concept can be populated in tissue_type_cd
	
	insert into tm_wz.wt_mrna_nodes
	(leaf_node
	,category_cd
	,platform
	,tissue_type
    ,attribute_1
	,attribute_2
	,node_type
	,orig_category_cd
	)
	select distinct substr(topNode || regexp_replace(replace(replace(replace(replace(replace(
	       substr(replace(category_cd,'+',bslash),1,instr(category_cd,'ATTR1')+5),'PLATFORM',title),'ATTR1',coalesce(attribute_1,'')),'ATTR2',coalesce(attribute_2,'')),'TISSUETYPE',coalesce(tissue_type,'')),'_',' ') || bslash,
		   '(\\){2,}', bslash),1,2000)
		  ,substr(category_cd,1,instr(category_cd,'ATTR1')+5)
		  ,case when instr(substr(category_cd,1,instr(category_cd,'ATTR1')+5),'PLATFORM') > 1 then platform else null end as platform
		  ,case when instr(substr(category_cd,1,instr(category_cd,'ATTR1')+5),'TISSUETYPE') > 1 then tissue_type else null end as tissue_type
		  ,attribute_1 as attribute_1
          ,case when instr(substr(category_cd,1,instr(category_cd,'ATTR1')+5),'ATTR2') > 1 then attribute_2 else null end as attribute_2
		  ,'ATTR1'
		  ,category_cd
	from  tm_wz.wt_mrna_node_values
	where category_cd like '%ATTR1%' escape ''
	  and attribute_1 is not null;  
	rowCount := ROW_COUNT;
    stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Create ATTR1 nodes in wt_mrna_nodes',rowCount,stepCt,'Done');
	raise notice 'after attr1';
	
	--	insert for ATTR2 node so ATTR2 concept can be populated in timepoint_cd
	
	insert into tm_wz.wt_mrna_nodes
	(leaf_node
	,category_cd
	,platform
	,tissue_type
    ,attribute_1
	,attribute_2
	,node_type
	,orig_category_cd
	)
	select distinct substr(topNode || regexp_replace(replace(replace(replace(replace(replace(
	       substr(replace(category_cd,'+',bslash),1,instr(category_cd,'ATTR2')+5),'PLATFORM',title),'ATTR1',coalesce(attribute_1,'')),'ATTR2',coalesce(attribute_2,'')),'TISSUETYPE',coalesce(tissue_type,'')),'_',' ') || bslash,
		   '(\\){2,}', bslash),1,2000)
		  ,substr(category_cd,1,instr(category_cd,'ATTR2')+5)
		  ,case when instr(substr(category_cd,1,instr(category_cd,'ATTR2')+5),'PLATFORM') > 1 then platform else null end as platform
		  ,case when instr(substr(category_cd,1,instr(category_cd,'ATTR1')+5),'TISSUETYPE') > 1 then tissue_type else null end as tissue_type
          ,case when instr(substr(category_cd,1,instr(category_cd,'ATTR2')+5),'ATTR1') > 1 then attribute_1 else null end as attribute_1
		  ,attribute_2 as attribute_2
		  ,'ATTR2'
		  ,category_cd
	from  tm_wz.wt_mrna_node_values
	where category_cd like '%ATTR2%' escape ''
	  and attribute_2 is not null; 
	rowCount := ROW_COUNT;
    stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Create ATTR2 nodes in wt_mrna_nodes',rowCount,stepCt,'Done');
	raise notice 'after attr2';
	
	--	insert for tissue_type node so sample_type_cd can be populated
	
	insert into tm_wz.wt_mrna_nodes
	(leaf_node
	,category_cd
	,platform
	,tissue_type
	,attribute_1
    ,attribute_2
	,node_type
	,orig_category_cd
	)
	select distinct substr(topNode || regexp_replace(replace(replace(replace(replace(replace(
	       substr(replace(category_cd,'+',bslash),1,instr(category_cd,'TISSUETYPE')+10),'PLATFORM',title),'ATTR1',coalesce(attribute_1,'')),'ATTR2',coalesce(attribute_2,'')),'TISSUETYPE',coalesce(tissue_type,'')),'_',' ') || bslash,
		   '(\\){2,}', bslash),1,2000)
		  ,substr(category_cd,1,instr(category_cd,'TISSUETYPE')+10)
		  ,case when instr(substr(category_cd,1,instr(category_cd,'TISSUETYPE')+10),'PLATFORM') > 1 then platform else null end as platform
		  ,tissue_type as tissue_type
		  ,case when instr(substr(category_cd,1,instr(category_cd,'TISSUETYPE')+10),'ATTR1') > 1 then attribute_1 else null end as attribute_1
          ,case when instr(substr(category_cd,1,instr(category_cd,'TISSUETYPE')+10),'ATTR2') > 1 then attribute_2 else null end as attribute_2
		  ,'TISSUETYPE'
		  ,category_cd
	from  tm_wz.wt_mrna_node_values
	where category_cd like '%TISSUETYPE%' escape '';   
	rowCount := ROW_COUNT;
    stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Create ATTR2 nodes in wt_mrna_nodes',rowCount,stepCt,'Done');
	raise notice 'after tissuetype';

	update tm_wz.wt_mrna_nodes t
	set node_name=x.node_name
	from (select distinct leaf_node,replace(substr(leaf_node,instr(leaf_node,bslash,-2)+1),bslash,'') as node_name
	      from tm_wz.WT_MRNA_NODES) x
	where t.leaf_node = x.leaf_node;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Updated node_name in DEAPP tmp_mrna_nodes',rowCount,stepCt,'Done');

	--	add leaf nodes for mRNA data  Only add nodes that do not already exist.

	FOR r_Nodes in 
		select distinct t.leaf_node
			  ,t.node_name
		from  tm_wz.wt_mrna_nodes t
		where not exists
		 (select 1 from i2b2metadata.i2b2 x
		  where t.leaf_node = x.c_fullname)
	Loop
		--Add nodes for all types (ALSO DELETES EXISTING NODE)
		call tm_cz.i2b2_add_node(TrialID, r_Nodes.leaf_node, r_Nodes.node_name, jobId);
		stepCt := stepCt + 1;
		tText := 'Added Leaf Node: ' || r_Nodes.leaf_node || '  Name: ' || r_Nodes.node_name;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,tText,1,stepCt,'Done');
		
	END LOOP;  

	--	update concept_cd for nodes, this is done to make the next insert easier

	update tm_wz.wt_mrna_nodes t
	set concept_cd=cd.concept_cd
	from i2b2demodata.concept_dimension cd
	where t.leaf_node = cd.concept_path
	  and t.concept_cd is null;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Update wt_mrna_nodes with newly created concept_cds',rowCount,stepCt,'Done');

	--	delete any concepts that are no longer valid
	
	for r_nodes in
		select c_fullname
		from i2b2metadata.i2b2
		where c_fullname in
			 (select distinct p.c_fullname
			  from deapp.de_subject_sample_mapping sm
				  ,i2b2metadata.i2b2 c
				  ,i2b2metadata.i2b2 p
			  where sm.trial_name = TrialId
				and sm.concept_code = c.c_basecode
				and c.c_fullname like p.c_fullname || '%' escape ''
				and p.c_fullname > topNode
				and sm.platform = 'MRNA_AFFYMETRIX'
				and sm.source_cd = sourceCd
			  minus
			  select distinct leaf_node as c_fullname
			  from tm_wz.wt_mrna_nodes)
	loop
		--	deletes unused nodes for a trial one at a time
		call tm_cz.i2b2_delete_1_node(r_Nodes.c_fullname,jobId);
		stepCt := stepCt + 1;
		tText := 'Deleted unused node: ' || r_Nodes.c_fullname;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,tText,1,stepCt,'Done');
	END LOOP;
	
	--	fill in any missing nodes
	
	call tm_cz.i2b2_fill_in_tree(TrialId, topNode, jobID);
	
	--	set sourcesystem_cd, c_comment to null if any added upper-level nodes
	
	update i2b2metadata.i2b2 b
	set sourcesystem_cd=null,c_comment=null
	where b.sourcesystem_cd = TrialId
	  and length(b.c_fullname) < length(topNode);
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Set sourcesystem_cd to null for added upper level nodes',rowCount,stepCt,'Done');
			 	
	
	--	Cleanup any existing data in de_subject_sample_mapping.  
/*
	delete from deapp.de_subject_sample_mapping 
	where trial_name = TrialID 
	  and coalesce(source_cd,'STD') = sourceCd
	  and platform = 'MRNA_AFFYMETRIX'; --Making sure only mRNA data is deleted
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete trial from DEAPP de_subject_sample_mapping',rowCount,stepCt,'Done');
*/

	--	delete any site/subject/samples that are not in lt_src_mrna_data for the trial on a reload

	delete from deapp.de_subject_sample_mapping sm
	where sm.trial_name = trial_id
	  and sm.source_cd = sourceCd
	  and sm.platform = 'MRNA_AFFYMETRIX'
	 and not exists
		 (select 1 from tm_lz.lt_src_mrna_subj_samp_map x
		  where coalesce(sm.site_id,'@') = coalesce(x.site_id,'@')
		    and sm.subject_id = x.subject_id
			and sm.sample_cd = x.sample_cd
			and sm.source_cd = coalesce(x.source_cd,'STD'));
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete dropped site/subject/sample from de_subject_sample_mapping',rowCount,stepCt,'Done');

  --Load the DE_SUBJECT_SAMPLE_MAPPING from wt_subject_mrna_data

  --PATIENT_ID      = PATIENT_ID (SAME AS ID ON THE PATIENT_DIMENSION)
  --SITE_ID         = site_id
  --SUBJECT_ID      = subject_id
  --SUBJECT_TYPE    = NULL
  --CONCEPT_CODE    = from LEAF records in wt_mrna_nodes
  --SAMPLE_TYPE    	= TISSUE_TYPE
  --SAMPLE_TYPE_CD  = concept_cd from TISSUETYPE records in wt_mrna_nodes
  --TRIAL_NAME      = TRIAL_NAME
  --TIMEPOINT		= attribute_2
  --TIMEPOINT_CD	= concept_cd from ATTR2 records in wt_mrna_nodes
  --TISSUE_TYPE     = attribute_1
  --TISSUE_TYPE_CD  = concept_cd from ATTR1 records in wt_mrna_nodes
  --PLATFORM        = MRNA_AFFYMETRIX - this is required by ui code
  --PLATFORM_CD     = concept_cd from PLATFORM records in wt_mrna_nodes
  --DATA_UID		= concatenation of concept_cd-patient_num
  --GPL_ID			= platform from wt_subject_mrna_data
  --CATEGORY_CD		= category_cd that generated ontology
  --SAMPLE_ID		= id of sample (trial:S:[site_id]:subject_id:sample_cd) from patient_dimension, may be the same as patient_num
  --SAMPLE_CD		= sample_cd
  --SOURCE_CD		= sourceCd
  
  --ASSAY_ID        = generated by trigger
  
	--	populate work table, original select too large for netezza
  
	execute immediate 'truncate table tm_wz.wt_subject_sample_mapping';
	
	--	pass 1 - insert leaf concept
  
	insert into tm_wz.wt_subject_sample_mapping
	(patient_num
	,site_id
	,subject_id	
	,concept_code
	,sample_type
	,sample_type_cd	
	,timepoint	
	,timepoint_cd
	,tissue_type	
	,tissue_type_cd	
	,platform
	,platform_cd
	,data_uid	
	,gpl_id			
	,sample_cd			
	,category_cd	
	)
	select distinct b.patient_num as patient_id
		  ,a.site_id
		  ,a.subject_id
		  ,ln.concept_cd as concept_code
		  ,a.tissue_type as sample_type
		  ,null as sample_type_cd
		  ,a.attribute_2 as timepoint
		  ,null as timepoint_cd
		  ,a.attribute_1 as tissue_type
		  ,null as tissue_type_cd
		  ,null as platform
		  ,null as platform_cd
		  ,ln.concept_cd || '-' || b.patient_num as data_uid
		  ,a.platform as gpl_id
		  ,a.sample_cd
		  ,coalesce(a.category_cd,'Biomarker_Data+Gene_Expression+PLATFORM+TISSUETYPE+ATTR1+ATTR2') as category_cd
	from tm_lz.lt_src_mrna_subj_samp_map a		
	--Joining to Pat_dim to ensure the ID's match. If not I2B2 won't work.
	inner join i2b2demodata.patient_dimension b
		  on  regexp_replace(TrialID || ':' || coalesce(a.site_id,'') || ':' || a.subject_id,'(::){1,}', ':') = b.sourcesystem_cd
	inner join tm_wz.wt_mrna_nodes ln
		  on  a.platform = ln.platform
		  and a.category_cd = ln.orig_category_cd
		  and a.tissue_type = ln.tissue_type
		  and coalesce(a.attribute_1,'@') = coalesce(ln.attribute_1,'@')
		  and coalesce(a.attribute_2,'@') = coalesce(ln.attribute_2,'@')
		  and a.category_cd = ln.category_cd
		  and ln.node_type = 'LEAF';
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert trial leaf into wt_subject_sample_mapping',rowCount,stepCt,'Done');

	--	pass 2 - update with platform concept
	update tm_wz.wt_subject_sample_mapping ssm
	set platform_cd=x.platform_cd
	from (select distinct b.patient_num
				,a.sample_cd
				,pn.concept_cd as platform_cd
		  from tm_lz.lt_src_mrna_subj_samp_map a		
		  --Joining to Pat_dim to ensure the ID's match. If not I2B2 won't work.
		  inner join i2b2demodata.patient_dimension b
				on regexp_replace(TrialID || ':' || coalesce(a.site_id,'') || ':' || a.subject_id,'(::){1,}', ':') = b.sourcesystem_cd
		  inner join tm_wz.wt_mrna_nodes pn
				on  a.platform = pn.platform
				and a.category_cd = pn.orig_category_cd
				and case when instr(substr(a.category_cd,1,instr(a.category_cd,'PLATFORM')+8),'TISSUETYPE') > 1 then a.tissue_type else '@' end = coalesce(pn.tissue_type,'@')
				and case when instr(substr(a.category_cd,1,instr(a.category_cd,'PLATFORM')+8),'ATTR1') > 1 then a.attribute_1 else '@' end = coalesce(pn.attribute_1,'@')
				and case when instr(substr(a.category_cd,1,instr(a.category_cd,'PLATFORM')+8),'ATTR2') > 1 then a.attribute_2 else '@' end = coalesce(pn.attribute_2,'@')
				and pn.node_type = 'PLATFORM') x
	where ssm.patient_num = x.patient_num
	  and ssm.sample_cd = x.sample_cd;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Update platform concept in wt_subject_sample_mapping',rowCount,stepCt,'Done');  
  
	-- pass 3 - update sample_type concept from tissue type
	
	update tm_wz.wt_subject_sample_mapping ssm
	set sample_type_cd=x.sample_type_cd
	from (select distinct b.patient_num
				,a.sample_cd
				,ttp.concept_cd as sample_type_cd
		  from tm_lz.lt_src_mrna_subj_samp_map a		
		  --Joining to Pat_dim to ensure the ID's match. If not I2B2 won't work.
		  inner join i2b2demodata.patient_dimension b
				on regexp_replace(TrialID || ':' || coalesce(a.site_id,'') || ':' || a.subject_id,'(::){1,}', ':') = b.sourcesystem_cd
		  left outer join tm_wz.wt_mrna_nodes ttp
				on  a.tissue_type = ttp.tissue_type
				and a.category_cd = ttp.orig_category_cd
				and case when instr(substr(a.category_cd,1,instr(a.category_cd,'TISSUETYPE')+10),'PLATFORM') > 1 then a.platform else '@' end = coalesce(ttp.platform,'@')
				and case when instr(substr(a.category_cd,1,instr(a.category_cd,'TISSUETYPE')+10),'ATTR1') > 1 then a.attribute_1 else '@' end = coalesce(ttp.attribute_1,'@')
				and case when instr(substr(a.category_cd,1,instr(a.category_cd,'TISSUETYPE')+10),'ATTR2') > 1 then a.attribute_2 else '@' end = coalesce(ttp.attribute_2,'@')
				and ttp.node_type = 'TISSUETYPE') x
	where ssm.patient_num = x.patient_num
	  and ssm.sample_cd = x.sample_cd;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Update tissue type in sample concept in wt_subject_sample_mapping',rowCount,stepCt,'Done');  
  
	--	pass 4 - update tissue type concept from attribute 1
	update tm_wz.wt_subject_sample_mapping ssm
	set tissue_type_cd=x.tissue_type_cd
	from (select distinct b.patient_num
				,a.sample_cd
				,a1.concept_cd as tissue_type_cd
		  from tm_lz.lt_src_mrna_subj_samp_map a		
		  --Joining to Pat_dim to ensure the ID's match. If not I2B2 won't work.
		  inner join i2b2demodata.patient_dimension b
				on  regexp_replace(TrialID || ':' || coalesce(a.site_id,'') || ':' || a.subject_id,'(::){1,}', ':') = b.sourcesystem_cd
  		  left outer join tm_wz.wt_mrna_nodes a1
				on  a.attribute_1 = a1.attribute_1
				and a.category_cd = a1.orig_category_cd
				and case when instr(substr(a.category_cd,1,instr(a.category_cd,'ATTR1')+5),'PLATFORM') > 1 then a.platform else '@' end = coalesce(a1.platform,'@')
				and case when instr(substr(a.category_cd,1,instr(a.category_cd,'ATTR1')+5),'TISSUETYPE') > 1 then a.tissue_type else '@' end = coalesce(a1.tissue_type,'@')
				and case when instr(substr(a.category_cd,1,instr(a.category_cd,'ATTR1')+5),'ATTR2') > 1 then a.attribute_2 else '@' end = coalesce(a1.attribute_2,'@')
				and a1.node_type = 'ATTR1') x
	where ssm.patient_num = x.patient_num
	  and ssm.sample_cd = x.sample_cd; 
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Update attribute 1 in tissue type concept in wt_subject_sample_mapping',rowCount,stepCt,'Done');  
    
	--	pass 5 - update timepoint concept from attribute 2
	
	update tm_wz.wt_subject_sample_mapping ssm
	set timepoint_cd=x.timepoint_cd
	from (select distinct b.patient_num
				,a.sample_cd
				,a2.concept_cd as timepoint_cd
		  from tm_lz.lt_src_mrna_subj_samp_map a		
		  --Joining to Pat_dim to ensure the ID's match. If not I2B2 won't work.
		  inner join i2b2demodata.patient_dimension b
				on  regexp_replace(TrialID || ':' || coalesce(a.site_id,'') || ':' || a.subject_id,'(::){1,}', ':') = b.sourcesystem_cd
  		  left outer join tm_wz.wt_mrna_nodes a2
				on 	a.attribute_2 = a2.attribute_2
				and a.category_cd = a2.orig_category_cd
				and case when instr(substr(a.category_cd,1,instr(a.category_cd,'ATTR2')+5),'PLATFORM') > 1 then a.platform else '@' end = coalesce(a2.platform,'@')
				and case when instr(substr(a.category_cd,1,instr(a.category_cd,'ATTR2')+5),'TISSUETYPE') > 1 then a.tissue_type else '@' end = coalesce(a2.tissue_type,'@')
				and case when instr(substr(a.category_cd,1,instr(a.category_cd,'ATTR2')+5),'ATTR1') > 1 then a.attribute_1 else '@' end = coalesce(a2.attribute_1,'@')
				and a2.node_type = 'ATTR2') x
	where ssm.patient_num = x.patient_num
	  and ssm.sample_cd = x.sample_cd; 
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Update attribute 2 in timepoint concept in wt_subject_sample_mapping',rowCount,stepCt,'Done');  
	

	--	update existing de_subject_sample_mapping records
	
	update deapp.de_subject_sample_mapping sm
	set concept_code=upd.concept_code
	   ,sample_type_cd=upd.sample_type_cd
	   ,timepoint_cd=upd.timepoint_cd
	   ,tissue_type_cd=upd.tissue_type_cd
	   ,category_cd=upd.category_cd
	   ,patient_id=upd.patient_id
	   ,data_uid=upd.data_uid
	   ,sample_type=upd.sample_type
	   ,tissue_type=upd.tissue_type
	   ,timepoint=upd.timepoint
	   ,omic_patient_id=upd.patient_id
	from (select TrialId as trial_name
		        ,v_source_cd as source_cd
				,site_id
				,subject_id
				,sample_cd
				,concept_code
				,sample_type_cd
				,timepoint_cd
				,tissue_type_cd
				,category_cd
				,patient_num as patient_id
				,data_uid
				,sample_type
				,tissue_type
				,timepoint
		  from tm_wz.wt_subject_sample_mapping
		 ) upd
	where sm.trial_name = upd.trial_name
	  and sm.source_cd = upd.source_cd
	  and coalesce(sm.site_id,'@') = coalesce(upd.site_id,'@')
	  and sm.subject_id = upd.subject_id
	  and sm.sample_cd = upd.sample_cd
	  and sm.platform = 'MRNA_AFFYMETRIX';
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Updated existing data in de_subject_sample_mappping',rowCount,stepCt,'Done');  
		  
	--	add new data to de_subject_sample_mapping
	  
	insert into deapp.de_subject_sample_mapping
	(patient_id
	,site_id
	,subject_id
	,subject_type
	,concept_code
	,assay_id
	,sample_type
	,sample_type_cd
	,trial_name
	,timepoint
	,timepoint_cd
	,tissue_type
	,tissue_type_cd
	,platform
	,platform_cd
	,data_uid
	,gpl_id
	,sample_id
	,sample_cd
	,category_cd
	,source_cd
	,omic_source_study
	,omic_patient_id
    )
	select t.patient_num
		  ,t.site_id
		  ,t.subject_id
		  ,null as subject_type
		  ,t.concept_code
		  ,next value for deapp.seq_assay_id
		  ,t.sample_type
		  ,t.sample_type_cd
		  ,TrialId
		  ,t.timepoint
		  ,t.timepoint_cd
		  ,t.tissue_type
		  ,t.tissue_type_cd
		  ,'MRNA_AFFYMETRIX'
		  ,t.platform_cd
		  ,t.data_uid
		  ,t.gpl_id
		  ,null as sample_id
		  ,t.sample_cd
		  ,t.category_cd
		  ,sourceCd
		  ,TrialId
		  ,t.patient_num
	from tm_wz.wt_subject_sample_mapping t
	where not exists
		  (select 1 from deapp.de_subject_sample_mapping sm
		   where sm.trial_name = TrialId
		     and sm.source_cd = v_source_cd
			 and coalesce(sm.site_id,'@') = coalesce(t.site_id,'@')
			 and sm.subject_id = t.subject_id
			 and sm.sample_cd = t.sample_cd
			 and sm.platform = 'MRNA_AFFYMETRIX');
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert trial into DEAPP de_subject_sample_mapping',rowCount,stepCt,'Done');

	--	Fail if no records exist in deapp.de_subject_sample_mapping
	
	select count(*) into pExists
	from deapp.de_subject_sample_mapping
	where trial_name = Trialid
	  and source_cd = v_source_cd
	  and platform = 'MRNA_AFFYMETRIX';
	
	if pExists = 0 then
		raise notice 'no subject_sample_mapping records inserted';
		call tm_cz.czx_write_audit(jobId,databasename,procedurename,'No records inserted into deapp.de_subject_sample_mapping',1,stepCt,'ERROR');
		call tm_cz.czx_ERROR_HANDLER(JOBID,PROCEDURENAME,'Application raised error');
		call tm_cz.czx_end_audit (jobId,'FAIL');
		return 16;
	end if;
		
	--	Insert records for patientsinto observation_fact

	insert into i2b2demodata.observation_fact
    (encounter_num
	,patient_num
	,concept_cd
	,modifier_cd
	,valtype_cd
	,tval_char
	,nval_num
	,sourcesystem_cd
	,import_date
	,valueflag_cd
	,provider_id
	,location_cd
	,units_cd
	,instance_num
    )
	select next value for i2b2demodata.seq_encounter_num
		  ,x.patient_id
		  ,x.concept_code
		  ,'@'
		  ,'T' -- Text data type
		  ,'E'  --Stands for Equals for Text Types
		  ,null	--	not numeric for mRNA
		  ,TrialId
		  ,runDate
		  ,'@'
		  ,'@'
		  ,'@'
		  ,'' -- no units available
		  ,1
	from (select distinct m.patient_id
			    ,m.concept_code
		  from  deapp.de_subject_sample_mapping m
		  where m.trial_name = TrialID 
			and m.source_cd = sourceCD
			and m.platform = 'MRNA_AFFYMETRIX') x;
	rowCount := ROW_COUNT;
    stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert patient facts into I2B2DEMODATA observation_fact',rowCount,stepCt,'Done');

	--Update I2b2 for correct data type

	update i2b2metadata.i2b2 b
	set c_columndatatype='T'
	   ,c_metadataxml=null
	   ,c_visualattributes=case when t.nbr_children = 1 then 'LAH' else 'FA' end
	from (select p.c_fullname, count(*) as nbr_children 
				 from tm_wz.wt_mrna_nodes t
				     ,i2b2metadata.i2b2 p
					,i2b2metadata.i2b2 c
				 where t.node_type = 'LEAF'
				   and t.leaf_node like p.c_fullname || '%' escape ''
				   and c.c_fullname like p.c_fullname || '%' escape '`'
				   and p.c_fullname > topNode
				   group by p.c_fullname) t
	where b.c_fullname = t.c_fullname;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Update visual attributes for leaf nodes in I2B2METADATA i2b2',rowCount,stepCt,'Done');

  --Build concept Counts
  --Also marks any i2B2 records with no underlying data as Hidden, need to do at Trial level because there may be multiple platform and there is no longer
  -- a unique top-level node for mRNA data
  
    call tm_cz.i2b2_create_concept_counts(topNode ,jobID );
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Create concept counts',0,stepCt,'Done');
	
	--	delete leaf nodes that are hidden
	
	FOR r_Nodes in 
		  select distinct c_fullname 
		  from  i2b2metadata.i2b2
		  where c_fullname like topNode || '%' escape ''
			and substr(c_visualattributes,2,1) = 'H'
	Loop
		--	deletes hidden nodes for a trial one at a time
		call tm_cz.i2b2_delete_1_node(r_Nodes.c_fullname,jobId);
		stepCt := stepCt + 1;
		tText := 'Deleted node: ' || r_Nodes.c_fullname;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,tText,1,stepCt,'Done');

	END LOOP;  	

  --Reload Security: Inserts one record for every I2B2 record into the security table

    call tm_cz.i2b2_load_security_data(jobId);
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Load security data',0,stepCt,'Done');

	--	tag data with probeset_id from reference.probeset_deapp

	execute immediate 'truncate table tm_wz.wt_subject_mrna_probeset';
	
	--	note: assay_id represents a unique subject/site/sample
	
	insert into tm_wz.wt_subject_mrna_probeset
	(probeset_id
	,intensity_value
	,patient_id
	,trial_name
	,assay_id
	)
	select gs.probeset_id
		  ,avg(cast(md.intensity_value as numeric(18,6)))
		  ,sd.patient_id
		  ,TrialId
		  ,sd.assay_id
	from deapp.de_subject_sample_mapping sd
		,tm_lz.lt_src_mrna_data md   
		,tm_cz.probeset_deapp gs
	where sd.sample_cd = md.expr_id
	  and sd.platform = 'MRNA_AFFYMETRIX'
	  and sd.trial_name = TrialId
	  and sd.source_cd = sourceCd
	  and sd.gpl_id = gs.platform
	  and md.probeset = gs.probeset
	  and case when dataType = 'R' 
			   then case when md.intensity_value > 0 
						 then 1 else 0 end
			   else 1 end = 1
	group by gs.probeset_id
		  ,sd.patient_id
		  ,sd.assay_id;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert into DEAPP wt_subject_mrna_probeset',rowCount,stepCt,'Done');	
	
	if rowCount = 0 then
		raise notice 'no records inserted into wt_mrna_probeset';
		call tm_cz.czx_write_audit(jobId,databasename,procedurename,'Unable to match probesets to platform in probeset_deapp',1,stepCt,'ERROR');
		call tm_cz.czx_ERROR_HANDLER(JOBID,PROCEDURENAME,'Application raised error');
		call tm_cz.czx_end_audit (jobId,'FAIL');
		return 16;
	end if;

	--	insert into de_subject_microarray_data when dataType is T (transformed)

	if dataType = 'T' then
		insert into deapp.de_subject_microarray_data
		(probeset_id
		,assay_id
		,patient_id
		,trial_name
		,zscore
		)
		select probeset_id
			  ,assay_id
			  ,patient_id
			  ,TrialId
			  ,case when intensity_value < -2.5
			        then -2.5
					when intensity_value > 2.5
					then 2.5
					else intensity_value
			   end as zscore
		from tm_wz.wt_subject_mrna_probeset
		where trial_name = TrialID;
		rowCount := ROW_COUNT;
		stepCt := stepCt + 1;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert transformed into DEAPP de_subject_microarray_data',rowCount,stepCt,'Done');	
	else
		--	Calculate ZScores and insert data into de_subject_microarray_data

		execute immediate 'truncate table tm_wz.wt_subject_microarray_logs';
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Truncate work tables in TM_WZ',0,stepCt,'Done');
		
		--	if dataType = L, use intensity_value as log_intensity
		--	if dataType = R, always use intensity_value
		if dataType = 'L' then
			insert into tm_wz.wt_subject_microarray_logs 
			(probeset_id
			,intensity_value
			,assay_id
			,log_intensity
			,patient_id
			,trial_name
			)
			select probeset_id
				  ,intensity_value  
				  ,assay_id 
				  ,intensity_value
				  ,patient_id
				  ,TrialId
			from tm_wz.wt_subject_mrna_probeset
			where trial_name = TrialId;
			rowCount := ROW_COUNT;
		else
			insert into tm_wz.wt_subject_microarray_logs 
			(probeset_id
			,intensity_value
			,assay_id
			,log_intensity
			,patient_id
			,trial_name
			)
			select probeset_id
				  ,intensity_value 
				  ,assay_id 
				  ,log(intensity_value)/log(2)
				  ,patient_id
				  ,TrialId
			from tm_wz.wt_subject_mrna_probeset
			where trial_name = TrialId;
			rowCount := ROW_COUNT;
		end if;
		stepCt := stepCt + 1;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Loaded data for trial in TM_WZ wt_subject_microarray_logs',rowCount,stepCt,'Done');

	--	calculate mean_intensity, median_intensity, and stddev_intensity per experiment, probe

		insert into tm_wz.wt_subject_microarray_calcs
		(trial_name
		,probeset_id
		,mean_intensity
		,median_intensity
		,stddev_intensity
		)
		select TrialId
			  ,d.probeset_id
			  ,avg(log_intensity)
			  ,percentile_cont(0.5) within group (order by log_intensity)
			  ,stddev(log_intensity)
		from tm_wz.wt_subject_microarray_logs d 
		group by d.trial_name 
				,d.probeset_id;
		rowCount := ROW_COUNT;
		stepCt := stepCt + 1;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Calculate intensities for trial in TM_WZ wt_subject_microarray_calcs',rowCount,stepCt,'Done');

		-- calculate zscore

		insert into tm_wz.wt_subject_microarray_med 
		(probeset_id
		,intensity_value
		,log_intensity
		,assay_id
		,mean_intensity
		,stddev_intensity
		,median_intensity
		,zscore
		,patient_id
		,trial_name
		)
		select d.probeset_id
			  ,d.intensity_value 
			  ,d.log_intensity 
			  ,d.assay_id  
			  ,c.mean_intensity 
			  ,c.stddev_intensity 
			  ,c.median_intensity 
			  ,round(CASE WHEN stddev_intensity=0 THEN 0 ELSE (log_intensity - median_intensity ) / stddev_intensity END,4)
			  ,d.patient_id
			  ,TrialId
		from tm_wz.wt_subject_microarray_logs d 
			,tm_wz.wt_subject_microarray_calcs c 
		where d.probeset_id = c.probeset_id
		  and d.trial_name = c.trial_name;
		rowCount := ROW_COUNT;
		stepCt := stepCt + 1;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Calculate Z-Score for trial in TM_WZ wt_subject_microarray_med',rowCount,stepCt,'Done');

		--	insert de_subject_microarray_data
		insert into deapp.de_subject_microarray_data
		(trial_name
		,assay_id
		,probeset_id
		,raw_intensity 
		,log_intensity
		,zscore
		,patient_id
		)
		select TrialId
			  ,m.assay_id
			  ,m.probeset_id 
			  ,round(case when dataType = 'R' then m.intensity_value
					when dataType = 'L' 
					then case when logBase = -1 then null else pow(logBase, m.log_intensity) end
					else null
					end,4) as raw_intensity
			  ,round(m.log_intensity,4)
			  ,round(CASE WHEN m.zscore < -2.5 THEN -2.5 WHEN m.zscore >  2.5 THEN  2.5 ELSE round(m.zscore,5) END,5)
			  ,m.patient_id
		from tm_wz.wt_subject_microarray_med m;
		rowCount := ROW_COUNT;
		stepCt := stepCt + 1;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert data for trial in DEAPP de_subject_microarray_data',rowCount,stepCt,'Done');
		
		--	cleanup tmp_ files

		execute immediate 'truncate table tm_wz.wt_subject_microarray_logs';
		execute immediate 'truncate table tm_wz.wt_subject_microarray_calcs';
		execute immediate 'truncate table tm_wz.wt_subject_microarray_med';

		stepCt := stepCt + 1;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Truncate work tables in TM_WZ',0,stepCt,'Done');

	end if;
	
    ---Cleanup OVERALL JOB if this proc is being run standalone
	
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'End i2b2_process_mrna_data',0,stepCt,'Done');

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

