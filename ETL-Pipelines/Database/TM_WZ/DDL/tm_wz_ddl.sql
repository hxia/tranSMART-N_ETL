--------------------------------------------------------
--  File created - Monday-October-21-2013   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Table WRK_CLINICAL_DATA
--------------------------------------------------------
   
CREATE TABLE TM_WZ."WRK_CLINICAL_DATA" 
   (	"STUDY_ID" VARCHAR(25), 
	"SITE_ID" VARCHAR(50), 
	"SUBJECT_ID" VARCHAR(20), 
	"VISIT_NAME" VARCHAR(100), 
	"DATA_LABEL" VARCHAR(500), 
	"DATA_VALUE" VARCHAR(500), 
	"CATEGORY_CD" VARCHAR(250), 
	"ETL_JOB_ID" NUMERIC(22,0), 
	"ETL_DATE" TIMESTAMP, 
	"USUBJID" VARCHAR(200), 
	"CATEGORY_PATH" VARCHAR(1000), 
	"DATA_TYPE" VARCHAR(10), 
	"DATA_LABEL_CTRL_VOCAB_CODE" VARCHAR(200), 
	"DATA_VALUE_CTRL_VOCAB_CODE" VARCHAR(500), 
	"DATA_LABEL_COMPONENTS" VARCHAR(1000), 
	"UNITS_CD" VARCHAR(50), 
	"VISIT_DATE" VARCHAR(50), 
	"NODE_NAME" VARCHAR(1000), 
	"LINK_TYPE" VARCHAR(20), 
	"LINK_VALUE" VARCHAR(200), 
	"END_DATE" VARCHAR(50), 
	"VISIT_REFERENCE" VARCHAR(100), 
	"DATE_IND" CHAR(1), 
	"OBS_STRING" VARCHAR(100), 
	"REC_NUM" NUMERIC(18,0), 
	"VALUETYPE_CD" VARCHAR(50),
	"LEAF_NODE" varchar(2000)
   ) ;

--------------------------------------------------------
--  DDL for Table WRK_MRNA_DATA
--------------------------------------------------------

CREATE TABLE TM_WZ."WRK_MRNA_DATA" 
   (	"PROBESET" VARCHAR(100), 
	"EXPR_ID" VARCHAR(100), 
	"RAW_INTENSITY" VARCHAR(50)
   ) ;

--------------------------------------------------------
--  DDL for Table WT_CLINICAL_DATA_DUPS
--------------------------------------------------------

CREATE TABLE TM_WZ."WT_CLINICAL_DATA_DUPS" 
   (	"SITE_ID" VARCHAR(50), 
	"SUBJECT_ID" VARCHAR(20), 
	"VISIT_NAME" VARCHAR(100), 
	"DATA_LABEL" VARCHAR(500), 
	"CATEGORY_CD" VARCHAR(250), 
	"LINK_VALUE" VARCHAR(500)
   ) ;

--------------------------------------------------------
--  DDL for Table WT_CLINICAL_ENCOUNTER
--------------------------------------------------------

CREATE TABLE TM_WZ."WT_CLINICAL_ENCOUNTER" 
   (	"LINK_TYPE" VARCHAR(20), 
	"LINK_VALUE" VARCHAR(500), 
	"ENCOUNTER_NUM" NUMERIC
   ) ;

--------------------------------------------------------
--  DDL for Table WT_DEL_NODES
--------------------------------------------------------

CREATE TABLE TM_WZ."WT_DEL_NODES" 
   (	"C_FULLNAME" VARCHAR(1000), 
	"C_BASECODE" VARCHAR(500)
   ) ;

--------------------------------------------------------
--  DDL for Table WT_FOLDER_NODES
--------------------------------------------------------

CREATE TABLE TM_WZ."WT_FOLDER_NODES" 
   (	"FOLDER_PATH" VARCHAR(700), 
	"FOLDER_NAME" VARCHAR(2000)
   ) ;

--------------------------------------------------------
--  DDL for Table WT_MIXED_TYPES
--------------------------------------------------------

CREATE TABLE TM_WZ."WT_MIXED_TYPES" 
   (	"CATEGORY_CD" VARCHAR(250), 
	"DATA_LABEL" VARCHAR(500), 
	"VISIT_NAME" VARCHAR(100)
   ) ;

--------------------------------------------------------
--  DDL for Table WT_MRNA_DATA
--------------------------------------------------------

CREATE TABLE TM_WZ."WT_MRNA_DATA" 
   (	"PROBESET" VARCHAR(100), 
	"EXPR_ID" VARCHAR(100), 
	"INTENSITY_VALUE" VARCHAR(50)
   ) ;

--------------------------------------------------------
--  DDL for Table WT_MRNA_NODES
--------------------------------------------------------

CREATE TABLE TM_WZ."WT_MRNA_NODES" 
   (	"LEAF_NODE" VARCHAR(2000), 
	"CATEGORY_CD" VARCHAR(2000), 
	"PLATFORM" VARCHAR(2000), 
	"TISSUE_TYPE" VARCHAR(2000), 
	"ATTRIBUTE_1" VARCHAR(2000), 
	"ATTRIBUTE_2" VARCHAR(2000), 
	"TITLE" VARCHAR(2000), 
	"NODE_NAME" VARCHAR(2000), 
	"CONCEPT_CD" VARCHAR(100), 
	"TRANSFORM_METHOD" VARCHAR(2000), 
	"NODE_TYPE" VARCHAR(50),
	"ORIG_CATEGORY_CD" VARCHAR(2000)
   ) ;
   
--------------------------------------------------------
--  DDL for Table WT_MRNA_NODE_VALUES
--------------------------------------------------------

CREATE TABLE TM_WZ."WT_MRNA_NODE_VALUES" 
   ("CATEGORY_CD" VARCHAR(2000), 
	"PLATFORM" VARCHAR(100), 
	"TISSUE_TYPE" VARCHAR(100), 
	"ATTRIBUTE_1" VARCHAR(200), 
	"ATTRIBUTE_2" VARCHAR(200), 
	"TITLE" VARCHAR(500), 
	"TRANSFORM_METHOD" VARCHAR(10)
   ) ;   

  
--------------------------------------------------------
--  DDL for Table WT_MRNA_SUBJ_SAMPLE_MAP
--------------------------------------------------------

CREATE TABLE TM_WZ."WT_MRNA_SUBJ_SAMPLE_MAP" 
   (	"TRIAL_NAME" VARCHAR(100), 
	"SITE_ID" VARCHAR(100), 
	"SUBJECT_ID" VARCHAR(100), 
	"SAMPLE_CD" VARCHAR(100), 
	"PLATFORM" VARCHAR(100), 
	"TISSUE_TYPE" VARCHAR(100), 
	"ATTRIBUTE_1" VARCHAR(256), 
	"ATTRIBUTE_2" VARCHAR(200), 
	"CATEGORY_CD" VARCHAR(200)
   ) ;

--------------------------------------------------------
--  DDL for Table WT_NUM_DATA_TYPES
--------------------------------------------------------

CREATE TABLE TM_WZ."WT_NUM_DATA_TYPES" 
   (	"CATEGORY_CD" VARCHAR(200), 
	"DATA_LABEL" VARCHAR(500), 
	"SAMPLE_TYPE" VARCHAR(100), 
	"VISIT_NAME" VARCHAR(100)
   ) ;

--------------------------------------------------------
--  DDL for Table WT_SUBJECT_INFO
--------------------------------------------------------

CREATE TABLE TM_WZ."WT_SUBJECT_INFO" 
   (	"USUBJID" VARCHAR(100), 
	"AGE_IN_YEARS_NUM" NUMERIC(3,0), 
	"SEX_CD" VARCHAR(50), 
	"RACE_CD" VARCHAR(50)
   ) ;

--------------------------------------------------------
--  DDL for Table WT_SUBJECT_MICROARRAY_CALCS
--------------------------------------------------------

CREATE TABLE TM_WZ."WT_SUBJECT_MICROARRAY_CALCS" 
   (	"TRIAL_NAME" VARCHAR(50), 
	"PROBESET_ID" NUMERIC(22,0), 
	"MEAN_INTENSITY" NUMERIC(18,6), 
	"MEDIAN_INTENSITY" NUMERIC(18,6), 
	"STDDEV_INTENSITY" NUMERIC(18,6)
   ) ;
--------------------------------------------------------
--  DDL for Table WT_SUBJECT_MICROARRAY_LOGS
--------------------------------------------------------

	CREATE TABLE TM_WZ."WT_SUBJECT_MICROARRAY_LOGS" 
   (	"PROBESET_ID" NUMERIC(22,0), 
	"INTENSITY_VALUE" NUMERIC(18,6),  
	"ASSAY_ID" NUMERIC(18,0), 
	"TRIAL_NAME" VARCHAR(50), 
	"LOG_INTENSITY" NUMERIC(18,6)
	,patient_id numeric(18,0)
   ) ;

--------------------------------------------------------
--  DDL for Table WT_SUBJECT_MICROARRAY_MED
--------------------------------------------------------
CREATE TABLE TM_WZ."WT_SUBJECT_MICROARRAY_MED" 
   (	"PROBESET_ID" NUMERIC(22,0), 
	"INTENSITY_VALUE" NUMERIC(28,6), 
	"LOG_INTENSITY" NUMERIC(18,6), 
	"ASSAY_ID" NUMERIC(18,0), 
	"PATIENT_ID" NUMERIC(18,0),  
	"TRIAL_NAME" VARCHAR(50), 
	"MEAN_INTENSITY" NUMERIC(18,6), 
	"STDDEV_INTENSITY" NUMERIC(18,6), 
	"MEDIAN_INTENSITY" NUMERIC(18,6), 
	"ZSCORE" NUMERIC(18,4)
   ) ;
   
--------------------------------------------------------
--  DDL for Table WT_SUBJECT_MRNA_DATA
--------------------------------------------------------

CREATE TABLE TM_WZ."WT_SUBJECT_MRNA_DATA" 
   (	"PROBESET" VARCHAR(500), 
	"EXPR_ID" VARCHAR(500), 
	"INTENSITY_VALUE" NUMERIC, 
	"ASSAY_ID" NUMERIC(18,0), 
	"PATIENT_ID" NUMERIC(22,0), 
	"SAMPLE_ID" NUMERIC(18,0), 
	"SUBJECT_ID" VARCHAR(100), 
	"TRIAL_NAME" VARCHAR(200), 
	"TIMEPOINT" VARCHAR(200), 
	"SAMPLE_TYPE" VARCHAR(200), 
	"PLATFORM" VARCHAR(200), 
	"TISSUE_TYPE" VARCHAR(200)
   ) ;

--------------------------------------------------------
--  DDL for Table WT_SUBJECT_MRNA_PROBESET
--------------------------------------------------------

   CREATE TABLE TM_WZ."WT_SUBJECT_MRNA_PROBESET" 
   (	"PROBESET_ID" NUMERIC(38,0), 
	"EXPR_ID" VARCHAR(500), 
	"INTENSITY_VALUE" NUMERIC(18,6), 
	"ASSAY_ID" NUMERIC(18,0), 
	"PATIENT_ID" NUMERIC(22,0), 
	"TRIAL_NAME" VARCHAR(200)
   ) ;

--------------------------------------------------------
--  DDL for Table WT_TRIAL_NODES
--------------------------------------------------------

CREATE TABLE TM_WZ."WT_TRIAL_NODES" 
   (	"LEAF_NODE" VARCHAR(4000), 
	"CATEGORY_CD" VARCHAR(200), 
	"VISIT_NAME" VARCHAR(100), 
	"SAMPLE_TYPE" VARCHAR(100), 
	"DATA_LABEL" VARCHAR(500), 
	"NODE_NAME" VARCHAR(500), 
	"DATA_VALUE" VARCHAR(500), 
	"DATA_TYPE" VARCHAR(20), 
	"DATA_LABEL_CTRL_VOCAB_CODE" VARCHAR(500), 
	"DATA_VALUE_CTRL_VOCAB_CODE" VARCHAR(500), 
	"DATA_LABEL_COMPONENTS" VARCHAR(1000), 
	"LINK_TYPE" VARCHAR(50), 
	"OBS_STRING" VARCHAR(100), 
	"VALUETYPE_CD" VARCHAR(50), 
	"REC_NUM" NUMERIC
   ) ;

--------------------------------------------------------
--  DDL for Table WT_VOCAB_NODES
--------------------------------------------------------

CREATE TABLE TM_WZ."WT_VOCAB_NODES" 
   (	"LEAF_NODE" VARCHAR(1000), 
	"MODIFIER_CD" VARCHAR(100), 
	"LABEL_NODE" VARCHAR(1000), 
	"VALUE_INSTANCE" NUMERIC(18,0), 
	"LABEL_INSTANCE" NUMERIC(18,0)
   ) ;

	create table tm_wz.wt_subject_sample_mapping
	(patient_num numeric(38,0),
	 site_id varchar(100),
	 subject_id	 varchar(100),
	 concept_code varchar(50),
	 sample_type varchar(100),
	 sample_type_cd varchar(100),
	 timepoint varchar(100),
	 timepoint_cd varchar(50),
	 tissue_type varchar(100),
	 tissue_type_cd varchar(50),
	 platform varchar(50),
	 platform_cd varchar(50),
	 data_uid varchar(100),
	 gpl_id varchar(20),
	 sample_cd varchar(200),
	 category_cd varchar(1000));

	