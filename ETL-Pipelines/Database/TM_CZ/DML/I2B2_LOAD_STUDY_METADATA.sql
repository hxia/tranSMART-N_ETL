CREATE OR REPLACE PROCEDURE TM_CZ.I2B2_LOAD_STUDY_METADATA(BIGINT)
RETURNS INT4
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
	currentJobID alias for $1;
  
	--Audit variables
	newJobFlag int4;
	databaseName VARCHAR(100);
	procedureName VARCHAR(100);
	jobID numeric(18,0);
	stepCt numeric(18,0);
	
	dcount 				int4;
	lcount 				int4;
	v_upload_date			timestamp;
	tmp_compound		varchar(200);
	tmp_disease			varchar(200);
	tmp_organism		varchar(200);
	tmp_ad_hoc_link		varchar(4000);
	tmp_pubmed			varchar(4000);
	link_repo			varchar(200);
	link_value			varchar(1000);
	tmp_study			varchar(200);
	tmp_property		varchar(200);
	pExists				int4;
	rowCount			numeric(18,0);
	pubmed_id			varchar(50);
	pubmed_title		varchar(4000);
	
	regexp_date			varchar(2000);
	regexp_numeric		varchar(1000);
	v_sqlerrm			varchar(1000);
	
	study_compound_rec	record;
	study_disease_rec	record;
	study_taxonomy_rec	record;
	study_link_rec		record;
	study_pubmed_rec	record;

BEGIN
    
	--Set Audit Parameters
	newJobFlag := 0; -- False (Default)
	jobID := currentJobID;

	databaseName := 'TM_CZ';
	procedureName := 'I2B2_LOAD_STUDY_METADATA';
	
	regexp_date := '^(?:(?:(?:(?:(?:1[6-9]|[2-9]\d)?(?:0[48]|[2468][048]|[13579][26])|(?:(?:16|[2468][048]|[3579][26])00)))(\/|-|\.)(?:0?2\1(?:29)))|(?:(?:(?:1[6-9]|[2-9]\d)?\d{2})(\/|-|\.)(?:(?:(?:0?[13578]|1[02])\2(?:31))|(?:(?:0?[1,3-9]|1[0-2])\2(29|30))|(?:(?:0?[1-9])|(?:1[0-2]))\2(?:0?[1-9]|1\d|2[0-8]))))$';
	regexp_numeric := '^[0-9]+(\.[0-9]+)?$';

	--Audit JOB Initialization
	--If Job ID does not exist, then this is a single procedure run and we need to create it
	IF(jobID IS NULL or jobID < 1)
	THEN
		newJobFlag := 1; -- True
		jobId := tm_cz.czx_start_audit (procedureName, databaseName);
	END IF;
  
	stepCt := 0;
	select now() into v_upload_date;
	
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Start procedure '|| procedureName,0,stepCt,'Done');
	
	--	delete existing metadata from lz_src_study_metadata
	
	delete from tm_lz.lz_src_study_metadata
	where study_id in (select distinct study_id from tm_lz.lt_src_study_metadata);
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete existing metadata in lz_src_study_metadata',rowCount,stepCt,'Done');

	--	insert metadata into lz_src_study_metadata
	
	insert into tm_lz.lz_src_study_metadata
	select x.*, v_upload_date
	from tm_lz.lt_src_study_metadata x;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert metadata in lz_src_study_metadata',rowCount,stepCt,'Done');
	
/*
	--	delete existing metadata from lz_src_study_metadata_ad_hoc
	
	delete from tm_lz.lz_src_study_metadata_ad_hoc
	where study_id in (select distinct study_id from tm_lz.lt_src_study_metadata);
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete existing metadata in lz_src_study_metadata_ad_hoc',rowCount,stepCt,'Done');

	--	insert metadata into lz_src_study_metadata_ad_hoc
	
	insert into tm_lz.lz_src_study_metadata_ad_hoc
	(study_id
	,ad_hoc_property_key
	,ad_hoc_property_value
	,ad_hoc_property_link
	,upload_date
	)
	select study_id
		  ,ad_hoc_property_key
		  ,ad_hoc_property_value
		  ,ad_hoc_property_link
		  ,v_upload_date
	from tm_lz.lt_src_study_metadata_ad_hoc x;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert metadata in lz_src_study_metadata_ad_hoc',rowCount,stepCt,'Done');
 */ 
	--	Update existing bio_experiment data

	update biomart.bio_experiment b
	set title=upd.title
	   ,description=upd.description
	   ,design=upd.design
	   ,start_date=upd.start_date
	   ,completion_date=upd.completion_date
	   ,primary_investigator=upd.primary_investigator
	   ,overall_design=upd.overall_design
	   ,institution=upd.institution
	   ,country=upd.country
	   ,bio_experiment_type=upd.bio_experiment_type
	   ,status=upd.status
	   ,contact_field=upd.contact_field
	   ,access_type=upd.access_type
	   ,biomarker_type=upd.biomarker_type
	   ,target=upd.target
	from (select m.study_id
				,m.title
				,m.description
				,m.design
				,case when cast(regexp_extract(m.start_date,regexp_date) as varchar(50)) is null
					  then null
					  else to_date(m.start_date,'YYYY/MM/DD')
					  end as start_date
				,case when cast(regexp_extract(m.completion_date,regexp_date) as varchar(50)) is null
					  then null
					  else to_date(m.completion_date,'YYYY/MM/DD')
					  end as completion_date
				,coalesce(m.primary_investigator,m.study_owner) as primary_investigator
				,m.overall_design
				,m.institution
				,m.country
				,'Experiment' as bio_experiment_type
				,m.status
				,m.contact_field
				,m.access_type
				,m.biomarker_type
				,m.target
		  from tm_lz.lt_src_study_metadata m
		  where m.study_id is not null) upd
	where b.accession = upd.study_id;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Updated trial data in BIOMART bio_experiment',rowCount,stepCt,'Done');

	--	Add new trial data to bio_experiment
	
	insert into biomart.bio_experiment
	(bio_experiment_id
	,bio_experiment_type
	,title
	,description
	,design
	,start_date
	,completion_date
	,primary_investigator
	,contact_field
	,etl_id
	,status
	,overall_design
	,accession
	,country
	,institution
	,access_type
	,biomarker_type
	,target
	)
	select next value for biomart.seq_bio_data_id
		  ,'Experiment'
	      ,m.title
		  ,m.description
		  ,m.design
		  ,case when cast(regexp_extract(m.start_date,regexp_date) as varchar(50)) is null
					  then null
					  else to_date(m.start_date,'YYYY/MM/DD')
					  end as start_date
		   ,case when cast(regexp_extract(m.completion_date,regexp_date) as varchar(50)) is null
					  then null
					  else to_date(m.completion_date,'YYYY/MM/DD')
					  end as completion_date
		  ,coalesce(m.primary_investigator,m.study_owner)
		  ,m.contact_field
		  ,'METADATA:' || m.study_id
		  ,m.status
		  ,m.overall_design
		  ,m.study_id
		  ,country
		  ,m.institution
		  ,m.access_type
		  ,m.biomarker_type
		  ,m.target
	from tm_lz.lt_src_study_metadata m
	where m.study_id is not null
	  and not exists
	      (select 1 from biomart.bio_experiment x
		   where m.study_id = x.accession);
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Inserted trial data in BIOMART bio_experiment',rowCount,stepCt,'Done');
	
	--	Insert new trial into bio_data_uid
	
	insert into biomart.bio_data_uid
	(bio_data_id
	,unique_id
	,bio_data_type
	)
	select distinct b.bio_experiment_id
	      ,'EXP:' || m.study_id
		  ,'EXP'
	from biomart.bio_experiment b
		,tm_lz.lt_src_study_metadata m
	where m.study_id is not null
	  and m.study_id = b.accession
	  and not exists
	      (select 1 from biomart.bio_data_uid x
		   where x.unique_id = 'EXP:' || m.study_id);
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Inserted trial data into BIOMART bio_data_uid',rowCount,stepCt,'Done');
	
	--	delete old data from bio_clinical_trial
	
	delete from biomart.bio_clinical_trial
	where trial_number in (select distinct m.study_id from tm_lz.lt_src_study_metadata m);
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete trial from bio_clinical_trial',rowCount,stepCt,'Done');
	
	--	Add new trial data to bio_clinical_trial
	
	insert into biomart.bio_clinical_trial
	(trial_number
	,study_owner
	,study_phase
	,blinding_procedure
	,studytype
	,duration_of_study_weeks
	,number_of_patients
	,number_of_sites
	,route_of_administration
	,dosing_regimen
	,group_assignment
	,type_of_control
	,completion_date
	,primary_end_points
	,secondary_end_points
	,inclusion_criteria
	,exclusion_criteria
	,subjects
	,gender_restriction_mfb
	,min_age
	,max_age
	,secondary_ids
	,bio_experiment_id
	,development_partner
	,main_findings
	,geo_platform
	--,platform_name
	,search_area
	)
	select m.study_id
          ,m.study_owner
          ,m.study_phase
          ,m.blinding_procedure
          ,m.studytype
		  ,case when cast(regexp_extract(m.duration_of_study_weeks,regexp_numeric) as varchar(50)) is null
					  then null
					  else m.duration_of_study_weeks
					  end as duration_of_study_weeks
		  ,case when cast(regexp_extract(m.number_of_patients,regexp_numeric) as varchar(50)) is null
					  then null
					  else m.number_of_patients
					  end as number_of_patients
		   ,case when cast(regexp_extract(m.number_of_sites,regexp_numeric) as varchar(50)) is null
					  then null
					  else m.number_of_sites
					  end as number_of_sites
          ,m.route_of_administration
          ,m.dosing_regimen
          ,m.group_assignment
          ,m.type_of_control
		  ,case when cast(regexp_extract(m.completion_date,regexp_date) as varchar(50)) is null
					  then null
					  else to_date(m.completion_date,'YYYY/MM/DD')
					  end as completion_date
          ,m.primary_end_points
          ,m.secondary_end_points
          ,m.inclusion_criteria
          ,m.exclusion_criteria
          ,m.subjects
          ,m.gender_restriction_mfb
		  ,case when cast(regexp_extract(m.min_age,regexp_numeric) as varchar(50)) is null
					  then null
					  else m.min_age
					  end as min_age
		  ,case when cast(regexp_extract(m.max_age,regexp_numeric) as varchar(50)) is null
					  then null
					  else m.max_age
					  end as max_age
          ,m.secondary_ids
          ,b.bio_experiment_id
		  ,m.development_partner
		  ,m.main_findings
		  ,m.geo_platform
		  --,m.platform_name
		  ,m.search_area
	from tm_lz.lt_src_study_metadata m
	    ,biomart.bio_experiment b
	where m.study_id is not null
	  and m.study_id = b.accession;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert trial into bio_clinical_trial',rowCount,stepCt,'Done');
	
	--	delete existing compound data for study, compound list may change
	
	delete from biomart.bio_data_compound dc
	where dc.bio_data_id in 
		 (select x.bio_experiment_id
		  from biomart.bio_experiment x
			  ,tm_lz.lt_src_study_metadata y
		  where x.accession = y.study_id
		    and x.etl_id = 'METADATA:' || y.study_id);
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete existing data from bio_data_compound',rowCount,stepCt,'Done');

	--	add compounds
	
	for study_compound_rec in
		select distinct study_id, compound
		from tm_lz.lt_src_study_metadata
		where compound is not null
	loop
		dCount := length(study_compound_rec.compound) - length(replace(study_compound_rec.compound,';',''))+1;
		while dcount > 0
		Loop	
			tmp_compound := tm_cz.parse_nth_value(study_compound_rec.compound,dcount,';');	   
			
			if tmp_compound is not null then
				--	add new compound		
				insert into biomart.bio_compound
				(bio_compound_id
				,generic_name)
				select next value for biomart.seq_bio_data_id
					  ,tmp_compound
				where not exists
					(select 1 from biomart.bio_compound x
					where upper(x.generic_name) = upper(tmp_compound));
				rowCount := ROW_COUNT;
				stepCt := stepCt + 1;
				call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Added compound to bio_compound',rowCount,stepCt,'Done');
	
				--	Insert new trial data into bio_data_compound

				insert into biomart.bio_data_compound
				(bio_data_id
				,bio_compound_id
				,etl_source
				)
				select b.bio_experiment_id
					  ,c.bio_compound_id
					  ,'METADATA:' || study_compound_rec.study_id
				from biomart.bio_experiment b
					,biomart.bio_compound c
				where upper(tmp_compound) = upper(c.generic_name) 
				  and tmp_compound is not null
				  and b.accession = study_compound_rec.study_id
				  and not exists
					 (select 1 from biomart.bio_data_compound x
					  where b.bio_experiment_id = x.bio_data_id
						and c.bio_compound_id = x.bio_compound_id);
				rowCount := ROW_COUNT;
				stepCt := stepCt + 1;
				call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Inserted trial data in BIOMART bio_data_compound',rowCount,stepCt,'Done');
			end if;
				
			dcount := dcount - 1;
		end loop;
	end loop;

	--	delete existing disease data for studies
	
	delete from biomart.bio_data_disease dc
	where dc.bio_data_id in 
		 (select x.bio_experiment_id
		  from biomart.bio_experiment x
			  ,tm_lz.lt_src_study_metadata y
		  where x.accession = y.study_id
		    and x.etl_id = 'METADATA:' || y.study_id);
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete existing data from bio_data_disease',rowCount,stepCt,'Done');

	--	add diseases
	
	for study_disease_rec in
		select distinct study_id, disease
		from tm_lz.lt_src_study_metadata
		where disease is not null
	loop
		dcount := length(study_disease_rec.disease) - length(replace(study_disease_rec.disease,';',''))+1;	 
		while dcount > 0
		Loop	
			tmp_disease := tm_cz.parse_nth_value(study_disease_rec.disease,dcount,';');
			   
			if tmp_disease is not null then
				--	add new disease
				insert into biomart.bio_disease
				(bio_disease_id
				,disease
				,prefered_name)
				select next value for biomart.seq_bio_data_id
					  ,tmp_disease
					  ,tmp_disease
				where not exists
					 (select 1 from biomart.bio_disease x
					  where upper(x.disease) = upper(tmp_disease));
				rowCount := ROW_COUNT;
				stepCt := stepCt + 1;
				call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Added disease to bio_disease',rowCount,stepCt,'Done');
							
				--	Insert new trial data into bio_data_disease

				insert into biomart.bio_data_disease
				(bio_data_id
				,bio_disease_id
				,etl_source
				)
				select b.bio_experiment_id
					  ,c.bio_disease_id
					  ,'METADATA:' || study_disease_rec.study_id
				from biomart.bio_experiment b
					,biomart.bio_disease c
				where upper(tmp_disease) = upper(c.disease) 
				  and b.accession = study_disease_rec.study_id
				  and not exists
						 (select 1 from biomart.bio_data_disease x
						  where b.bio_experiment_id = x.bio_data_id
							and c.bio_disease_id = x.bio_disease_id);
				rowCount := ROW_COUNT;
				stepCt := stepCt + 1;
				call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Inserted trial data in BIOMART bio_data_disease',rowCount,stepCt,'Done');
			end if;	
			dcount := dcount - 1;
		end loop;
	end loop;

	--	delete existing taxonomy data for studies
	
	delete from biomart.bio_data_taxonomy dc
	where dc.bio_data_id in 
		 (select x.bio_experiment_id
		  from biomart.bio_experiment x
			  ,tm_lz.lt_src_study_metadata y
		  where x.accession = y.study_id
		    and x.etl_id = 'METADATA:' || y.study_id);
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete existing data from bio_data_taxonomy',rowCount,stepCt,'Done');

	--	add taxonomy for study
	
	for study_taxonomy_rec in
		select distinct study_id, organism
		from tm_lz.lt_src_study_metadata
		where organism is not null
	loop
		dcount := length(study_taxonomy_rec.organism) - length(replace(study_taxonomy_rec.organism,';',''))+1;
		while dcount > 0
		Loop	
			tmp_organism := tm_cz.parse_nth_value(study_taxonomy_rec.organism,dcount,';');
			if tmp_organism is not null then
				--	add new organism
				
				insert into biomart.bio_taxonomy
				(bio_taxonomy_id
				,taxon_name
				,taxon_label)
				select next value for biomart.seq_bio_data_id
					  ,tmp_organism
					  ,tmp_organism
				where not exists
					 (select 1 from bio_taxonomy x
					  where upper(x.taxon_name) = upper(tmp_organism))
				  and tmp_organism is not null;
				rowCount := ROW_COUNT;
				stepCt := stepCt + 1;
				call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Added organism to bio_taxonomy',rowCount,stepCt,'Done');
							
				--	Insert new trial data into bio_data_taxonomy

				insert into biomart.bio_data_taxonomy
				(bio_data_id
				,bio_taxonomy_id
				,etl_source
				)
				select b.bio_experiment_id
					  ,c.bio_taxonomy_id
					  ,'METADATA:' || study_taxonomy_rec.study_id
				from biomart.bio_experiment b
					,biomart.bio_taxonomy c
				where upper(tmp_organism) = upper(c.taxon_name) 
				  and tmp_organism is not null
				  and b.accession = study_taxonomy_rec.study_id
				  and not exists
						 (select 1 from biomart.bio_data_taxonomy x
						  where b.bio_experiment_id = x.bio_data_id
							and c.bio_taxonomy_id = x.bio_taxonomy_id);
				rowCount := ROW_COUNT;
				stepCt := stepCt + 1;
				call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Inserted trial data in BIOMART bio_data_taxonomy',rowCount,stepCt,'Done');
			end if;			
			dcount := dcount - 1;
		end loop;
	end loop;

	--	Create i2b2_tags
	
	delete from i2b2metadata.i2b2_tags
	where upper(tag_type) = 'TRIAL';
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete existing Trial tags in i2b2_tags',rowCount,stepCt,'Done');
	
	insert into i2b2metadata.i2b2_tags
	(tag_id, path, tag, tag_type, tags_idx)
	select next value for i2b2metadata.sq_i2b2_tag_id
		  ,x.path
		  ,x.tag
		  ,x.tag_type
		  ,x.tags_idx
	from (select min(b.c_fullname) as path
		  		,be.accession as tag
		  		,'Trial' as tag_type
		  		,0 as tags_idx
		  from biomart.bio_experiment be
			  ,i2b2metadata.i2b2 b
		  where be.accession = b.sourcesystem_cd
		  group by be.accession) x;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Add Trial tag in i2b2_tags',rowCount,stepCt,'Done');

	--	GPL 1.0 code
	
	--	add ncbi/GEO linking
	
	--	check if ncbi exists in bio_content_repository, if not, add
	
	select count(*) into dcount
	from biomart.bio_content_repository
	where repository_type = 'NCBI'
	  and location_type = 'URL';
	
	if dcount = 0 then
		insert into biomart.bio_content_repository
		(bio_content_repo_id
		,location
		,active_y_n
		,repository_type
		,location_type) 
		select next value for biomart.seq_bio_data_id
			  ,'http://www.ncbi.nlm.nih.gov/'
			  ,'Y'
			  ,'NCBI'
			  ,'URL';
		rowCount := ROW_COUNT;
		stepCt := stepCt + 1;
		call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Inserted NCBI URL in bio_content_repository',rowCount,stepCt,'Done');	
	end if;

	--	insert GSE studies into bio_content
	
	insert into biomart.bio_content
	(bio_file_content_id
	,repository_id
	,location
	,file_type
	,etl_id_c
	)
	select next value for biomart.seq_bio_data_id
		  ,bcr.bio_content_repo_id
		  ,'geo/query/acc.cgi?acc=' || m.study_id
		  ,'Experiment Web Link'
		  ,'METADATA:' || m.study_id
	from tm_lz.lt_src_study_metadata m
		,biomart.bio_content_repository bcr
	where m.study_id like 'GSE%' escape ''
	  and bcr.repository_type = 'NCBI'
	  and bcr.location_type = 'URL'
	  and not exists
		 (select 1 from biomart.bio_content x
		  where x.etl_id_c like '%' || m.study_id || '%' escape ''
		    and x.file_type = 'Experiment Web Link'
			and x.location = 'geo/query/acc.cgi?acc=' || m.study_id);
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Inserted GEO study into bio_content',rowCount,stepCt,'Done');
	
	--	insert GSE studies into bio_content_reference
	
	insert into biomart.bio_content_reference
	(bio_content_reference_id
	,bio_content_id
	,bio_data_id
	,content_reference_type
	,etl_id_c
	)
	select next value for biomart.seq_bio_data_id
		  ,bc.bio_file_content_id
		  ,be.bio_experiment_id
		  ,'Experiment Web Link'
		  ,'METADATA:' || m.study_id
	from tm_lz.lt_src_study_metadata m
		,biomart.bio_experiment be
		,biomart.bio_content bc
	where m.study_id like 'GSE%' escape ''
	  and m.study_id = be.accession
	  and bc.file_type = 'Experiment Web Link'
	  and bc.etl_id_c = 'METADATA:' || m.study_id
	  and bc.location = 'geo/query/acc.cgi?acc=' || m.study_id
	  and not exists
		 (select 1 from biomart.bio_content_reference x
		  where bc.bio_file_content_id = x.bio_content_id
		    and be.bio_experiment_id = x.bio_data_id);
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Inserted GEO study into bio_content_reference',rowCount,stepCt,'Done');

	--	add PUBMED linking
	
	--	delete existing pubmed data for studies
	
	delete from biomart.bio_content_reference dc
	where dc.bio_content_id in 
		 (select x.bio_file_content_id
		  from biomart.bio_content x
			  ,tm_lz.lt_src_study_metadata y
		  where x.file_type = 'Publication Web Link'
		    and x.etl_id_c = 'METADATA:' || y.study_id);
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete existing Pubmed data from bio_content_reference',rowCount,stepCt,'Done');		
			
	delete from biomart.bio_content dc
	where dc.bio_file_content_id in 
		 (select x.bio_file_content_id
		  from biomart.bio_content x
			  ,tm_lz.lt_src_study_metadata y
		  where x.file_type = 'Publication Web Link'
		    and x.etl_id_c = 'METADATA:' || y.study_id);
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete existing Pubmed data from bio_content',rowCount,stepCt,'Done');
	
	--	Check if pubmed link exists, if not, add
	
	select count(*) into dCount
	from tm_lz.lt_src_study_metadata
	where pubmed_ids is not null;
	
	if dCount > 0 then
		select count(*) into dcount
		from biomart.bio_content_repository
		where repository_type = 'PubMed';	
	
		if dcount = 0 then
			insert into biomart.bio_content_repository
			(bio_content_repo_id
			,location
			,active_y_n
			,repository_type
			,location_type) 
			select next value for biomart.seq_bio_data_id
				  ,'http://www.ncbi.nlm.nih.gov/pubmed/'
				  ,'Y'
				  ,'PubMed'
				  ,'URL';
			rowCount := ROW_COUNT;
			stepCt := stepCt + 1;
			call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Inserted GEO study into bio_content_reference',rowCount,stepCt,'Done');
		end if;
	end if;
		
	--	loope through pubmed ids
	
	for study_pubmed_rec in
		select distinct study_id, pubmed_ids
		from tm_lz.lt_src_study_metadata
		where pubmed_ids is not null
	loop
		dCount := length(study_pubmed_rec.pubmed_ids)-length(replace(study_pubmed_rec.pubmed_ids,'|',''))+1;
		while dcount > 0
		loop	
			-- multiple pubmed id can be separated by |, pubmed id and title are separated by @
			tmp_pubmed := tm_cz.parse_nth_value(study_pubmed_rec.pubmed_ids,dcount,'|');		
			lCount := instr(tmp_pubmed,'@');
			if lcount = 0 then
				pubmed_id := tmp_pubmed;
				pubmed_title := null;
				stepCt := stepCt + 1;
				call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'pubmed_id: ' || pubmed_id,1,stepCt,'Done');
			else
				pubmed_id := substr(tmp_pubmed,1,instr(tmp_pubmed,'@')-1);
				stepCt := stepCt + 1;
				call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'pubmed_id: ' || pubmed_id,1,stepCt,'Done');	
				pubmed_title := substr(tmp_pubmed,instr(tmp_pubmed,'@')+1);
				stepCt := stepCt + 1;
				call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'pubmed_title: ' || pubmed_title,1,stepCt,'Done');
			end if;
	
			insert into biomart.bio_content
			(bio_file_content_id
			,repository_id
			,location
			,title
			,file_type
			,etl_id_c
			)
			select next value for biomart.seq_bio_data_id
				  ,bcr.bio_content_repo_id
				  ,pubmed_id
				  ,pubmed_title
				  ,'Publication Web Link'
				  ,'METADATA:' || study_pubmed_rec.study_id
			from biomart.bio_content_repository bcr
			where bcr.repository_type = 'PubMed'
			  and not exists
				 (select 1 from biomart.bio_content x
				  where x.etl_id_c like '%' || study_pubmed_rec.study_id || '%' escape ''
				    and x.file_type = 'Publication Web Link'
					and x.location = pubmed_id);
			rowCount := ROW_COUNT;
			stepCt := stepCt + 1;
			call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Inserted pubmed for study into bio_content',rowCount,stepCt,'Done');
			
			insert into biomart.bio_content_reference
				(bio_content_reference_id
				,bio_content_id
				,bio_data_id
				,content_reference_type
				,etl_id_c
				)
				select next value for biomart.seq_bio_data_id
					  ,bc.bio_file_content_id
					  ,be.bio_experiment_id
					  ,'Publication Web Link'
					  ,'METADATA:' || study_pubmed_rec.study_id
				from biomart.bio_experiment be
					,biomart.bio_content bc
				where be.accession = study_pubmed_rec.study_id
				  and bc.file_type = 'Publication Web Link'
				  and bc.etl_id_c = 'METADATA:' || study_pubmed_rec.study_id
				  and bc.location = pubmed_id
				  and not exists
					 (select 1 from biomart.bio_content_reference x
					  where bc.bio_file_content_id = x.bio_content_id
						and be.bio_experiment_id = x.bio_data_id);
			rowCount := ROW_COUNT;
			stepCt := stepCt + 1;
			call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Inserted pubmed for study into bio_content_reference',rowCount,stepCt,'Done');
			dcount := dcount - 1;
		end loop;
	end loop;	

	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'End i2b2_load_study_metadata',rowCount,stepCt,'Done');
	
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

