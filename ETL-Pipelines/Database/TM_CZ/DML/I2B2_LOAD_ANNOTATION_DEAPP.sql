CREATE OR REPLACE PROCEDURE TM_CZ.I2B2_LOAD_ANNOTATION_DEAPP(NUMERIC(18,0))
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
	currentJobID alias for $1;
	
	--Audit variables
	newJobFlag int4;
	databaseName character varying(100);
	procedureName character varying(100);
	jobID bigint;
	stepCt numeric(18,0);
	rowCount	numeric(18,0);
	
	gplId	varchar(100);
	v_sqlerrm	varchar(1000);
	

BEGIN

	stepCt := 0;

	--Set Audit Parameters
	newJobFlag := 0; -- False (Default)
	jobID := currentJobID;

	databaseName := 'TM_CZ';
	procedureName := 'I2B2_LOAD_ANNOTATION_DEAPP';

	--Audit JOB Initialization
	--If Job ID does not exist, then this is a single procedure run and we need to create it
	IF(jobID IS NULL or jobID < 1)
	THEN
		newJobFlag := 1; -- True
		JobId := tm_cz.czx_start_audit (procedureName, databaseName);
	END IF;

	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Starting i2b2_load_annotation_deapp',0,stepCt,'Done');

	--	get GPL id from external table
	
	select distinct gpl_id into gplId from tm_lz.lt_src_deapp_annot;
	
	--	delete any existing data from annotation_deapp
	
	delete from tm_cz.annotation_deapp
	where gpl_id = gplId;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete existing data from annotation_deapp',rowCount,stepCt,'Done');
	
	--	delete any existing data from deapp.de_mrna_annotation
	
	delete from deapp.de_mrna_annotation
	where gpl_id = gplId;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete existing data from de_mrna_annotation',rowCount,stepCt,'Done');
	
	--	update organism for existing probesets in probeset_deapp

	update tm_cz.probeset_deapp p
	set organism=t.organism 
	from (select distinct gpl_id, probe_id, organism from tm_lz.LT_SRC_DEAPP_ANNOT) t
	where t.gpl_id = p.platform
	  and p.probeset = t.probe_id;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Update organism in probeset_deapp',ROW_COUNT,stepCt,'Done');

	--	insert any new probesets into probeset_deapp

	insert into tm_cz.probeset_deapp
	(probeset_id
	,probeset
	,organism
	,platform)
	select next value for tm_cz.SEQ_PROBESET_ID
		  ,y.probe_id
		  ,y.organism
		  ,y.gpl_id
	from (select distinct probe_id
				,coalesce(organism,'Homo sapiens') as organism
				,gpl_id
		 from tm_lz.lt_src_deapp_annot t
		 where not exists
			  (select 1 from tm_cz.probeset_deapp x
			   where t.gpl_id = x.platform
		    and t.probe_id = x.probeset
			and coalesce(t.organism,'Homo sapiens') = coalesce(x.organism,'Homo sapiens'))
		  ) y;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert new probesets into probeset_deapp',rowCount,stepCt,'Done');

	--	insert data into annotation_deapp

	insert into tm_cz.annotation_deapp
	(gpl_id
	,probe_id
	,gene_symbol
	,gene_id
	,probeset_id
	,organism)
	select distinct d.gpl_id
	,d.probe_id
	,d.gene_symbol
	,d.gene_id
	,p.probeset_id
	,coalesce(d.organism,'Homo sapiens')
	from tm_lz.lt_src_deapp_annot d
	,tm_cz.probeset_deapp p
	where d.probe_id = p.probeset
	  and d.gpl_id = p.platform
	  and coalesce(d.organism,'Homo sapiens') = coalesce(p.organism,'Homo sapiens');
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Load annotation data into REFERENCE annotation_deapp',rowCount,stepCt,'Done');
	
	--	insert data into deapp.de_mrna_annotation

	insert into deapp.de_mrna_annotation
	(gpl_id
	,probe_id
	,gene_symbol
	,gene_id
	,probeset_id
	,organism)
	select distinct d.gpl_id
	,d.probe_id
	,d.gene_symbol
	,case when d.gene_id is null then null else d.gene_id::bigint end
	,p.probeset_id
	,coalesce(d.organism,'Homo sapiens')
	from tm_lz.lt_src_deapp_annot d
	,tm_cz.probeset_deapp p
	where d.probe_id = p.probeset
	  and d.gpl_id = p.platform
	  and coalesce(d.organism,'Homo sapiens') = coalesce(p.organism,'Homo sapiens');	
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Load annotation data into DEAPP de_mrna_annotation',rowCount,stepCt,'Done');

	--	update gene_id if null
	
	update deapp.de_mrna_annotation t
	set gene_id=upd.gene_id
	from (select b.bio_marker_name as gene_symbol
			     ,min(b.primary_external_id) as gene_id
				 ,b.organism
				 from biomart.bio_marker b
				 where upper(b.bio_marker_type) = 'GENE'
				 group by b.bio_marker_name, b.organism) upd
	where t.gene_symbol = upd.gene_symbol
	  and upper(t.organism) = upper(upd.organism)
	  and t.gpl_id = gplId
	  and t.gene_id is null
	  and t.gene_symbol is not null;		
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Updated missing gene_id in de_mrna_annotation',rowCount,stepCt,'Done');
	
	--	update gene_symbol based on gene_id.  This is done to correct any mislabeling of the gene symbol from the annotation file
	
	update deapp.de_mrna_annotation t
	set gene_symbol=upd.gene_symbol
	from (select b.primary_external_id as gene_id
			     ,min(b.bio_marker_name) as gene_symbol
				 ,b.organism
				 from biomart.bio_marker b
				 where upper(b.bio_marker_type) = 'GENE'
				 group by b.primary_external_id, b.organism) upd
	where t.gene_id = upd.gene_id
	  and upper(t.organism) = upper(upd.organism)
	  and t.gpl_id = gplId
	  and t.gene_id is null
	  and t.gene_symbol is not null;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Updated gene_symbol in de_mrna_annotation',rowCount,stepCt,'Done');
	
	--	insert probesets into biomart.bio_assay_feature_group
	
	insert into biomart.bio_assay_feature_group
	(bio_assay_feature_group_id
	,feature_group_name
	,feature_group_type)
	select next value for biomart.seq_bio_data_id
		  ,t.probe_id
		  ,'PROBESET'
	from (select distinct probe_id
		  from tm_lz.lt_src_deapp_annot) t
	where not exists
		 (select 1 from biomart.bio_assay_feature_group x
		  where t.probe_id = x.feature_group_name);	
	rowCount := ROW_COUNT;	 
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert probesets into biomart.bio_assay_feature_group',rowCount,stepCt,'Done');
	
	--	insert probesets into biomart.bio_assay_data_annotation
	
	insert into biomart.bio_assay_data_annotation
	(bio_assay_feature_group_id
	,bio_marker_id)
	select distinct fg.bio_assay_feature_group_id
		  ,coalesce(bgs.bio_marker_id,bgi.bio_marker_id)
	from tm_lz.lt_src_deapp_annot t
		 inner join biomart.bio_assay_feature_group fg
		 	   on t.probe_id = fg.feature_group_name
		 left outer join biomart.bio_marker bgs
		 	   on t.gene_symbol = bgs.bio_marker_name
		 left outer join biomart.bio_marker bgi
		  	   on t.gene_id = bgi.primary_external_id
	where (t.gene_symbol is not null or t.gene_id is not null)
	  and upper(coalesce(t.organism,'Homo sapiens')) = upper(coalesce(bgs.organism,'Homo sapiens'))
	  and upper(coalesce(t.organism,'Homo sapiens')) = upper(coalesce(bgi.organism,'Homo sapiens'))
	  and coalesce(bgs.bio_marker_id,bgi.bio_marker_id,-1) > 0
	  and not exists
		 (select 1 from biomart.bio_assay_data_annotation x
		  where fg.bio_assay_feature_group_id = x.bio_assay_feature_group_id
		    and coalesce(bgs.bio_marker_id,bgi.bio_marker_id,-1) = x.bio_marker_id);
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Link feature_group to bio_marker in biomart.bio_assay_data_annotation',rowCount,stepCt,'Done');

	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'End i2b2_load_annotation_deapp',0,stepCt,'Done');
	
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

