CREATE OR REPLACE PROCEDURE TM_CZ.I2B2_LOAD_EQTL_TOP50 
(bigint
,bigint
)
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
	
	i_bio_assay_analysis_id	alias for $1;
	currentJobID alias for $2;
	
	--Audit variables
	newJobFlag int4;
	databaseName VARCHAR(100);
	procedureName VARCHAR(100);
	jobID numeric(18,0);
	stepCt numeric(18,0);
	rowCount		numeric(18,0);
	tExists		int4;
	v_sqlerrm		varchar(1000);
	
begin

	stepCt := 0;
	rowCount := 0;
	
	--Set Audit Parameters
	newJobFlag := 0; -- False (Default)
	jobID := currentJobID;

	databaseName := 'TM_CZ';
	procedureName := 'I2B2_LOAD_EQTL_TOP50';
	
	--Audit JOB Initialization
	--If Job ID does not exist, then this is a single procedure run and we need to create it
	IF(jobID IS NULL or jobID < 1)
	THEN
		newJobFlag := 1; -- True
		jobId := tm_cz.czx_start_audit (procedureName, databaseName);
	END IF;
	
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Start ' || procedureName,0,stepCt,'Done');
	
	delete from biomart.bio_asy_analysis_eqtl_top50
	where bio_assay_analysis_id = i_bio_assay_analysis_id;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Delete analysis from bio_asy_analysis_eqtl_top50',rowCount,stepCt,'Done');
	
	insert into biomart.bio_asy_analysis_eqtl_top50
	(bio_assay_analysis_id
	,analysis
	,chrom
	,pos
	,rsgene
	,rsid
	,pvalue
	,logpvalue
	,extdata
	,rnum
	)
	select a.*
	from (select eqtl.bio_assay_analysis_id
				,baa.analysis_name as analysis
				,info.chrom as chrom
				,info.pos as pos
				,info.gene_name as rsgene
				,eqtl.rs_id as rsid
				,eqtl.p_value as pvalue
				,eqtl.log_p_value as logpvalue
				,eqtl.ext_data as extdata
				,row_number () over (order by eqtl.p_value asc, eqtl.rs_id asc) as rnum
		  from biomart.bio_assay_analysis_eqtl eqtl 
		  inner join biomart.bio_assay_analysis baa 
				on  baa.bio_assay_analysis_id = eqtl.bio_assay_analysis_id
		  inner join deapp.de_rc_snp_info info 
				on  eqtl.rs_id = info.rs_id 
				and hg_version='19'
		  where eqtl.bio_assay_analysis_id = i_bio_assay_analysis_id) a
	where a.rnum < 500;
	rowCount := ROW_COUNT;
	stepCt := stepCt + 1;
	call tm_cz.czx_write_audit(jobId,databaseName,procedureName,'Insert into bio_asy_analysis_eqtl_top50',rowCount,stepCt,'Done');
	
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
	
