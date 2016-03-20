-- CREATE SCHEMA TM_CZ;

CREATE SEQUENCE tm_cz.seq_cz INCREMENT BY 1 MINVALUE 1 MAXVALUE 9999999999 START WITH 1;

CREATE SEQUENCE tm_cz.seq_cz_job_audit INCREMENT BY 1 MINVALUE 1 NO MAXVALUE START WITH 1;

CREATE SEQUENCE tm_cz.seq_cz_job_id INCREMENT BY 1 MINVALUE 1 NO MAXVALUE START WITH 1;

CREATE SEQUENCE tm_cz.seq_cz_job_master INCREMENT BY 1 MINVALUE 1 NO MAXVALUE START WITH 1;

CREATE SEQUENCE tm_cz.seq_cz_job_message INCREMENT BY 1 MINVALUE 1 NO MAXVALUE START WITH 1;


CREATE SEQUENCE tm_cz.seq_probeset_id INCREMENT BY 1 MINVALUE 1 MAXVALUE 99999999 START WITH 1;


CREATE TABLE tm_cz.cz_job_audit (
	seq_id bigint NOT NULL,
	job_id bigint NOT NULL,
	database_name varchar(50),
	procedure_name varchar(100),
	step_desc varchar(1000),
	step_status varchar(50),
	records_manipulated bigint,
	step_number bigint,
	job_date timestamp,
	time_elapsed_secs numeric(18,3) DEFAULT 0
);

ALTER TABLE tm_cz.cz_job_audit ADD CONSTRAINT cz_job_audit_pk PRIMARY KEY (seq_id);


CREATE TABLE tm_cz.cz_job_message (
	job_id bigint NOT NULL,
	message_id bigint,
	message_line bigint,
	message_procedure varchar(100),
	info_message varchar(2000),
	seq_id bigint NOT NULL
);


CREATE TABLE tm_cz.cz_job_error (
	job_id bigint NOT NULL,
	error_number varchar(30),
	error_message varchar(1000),
	error_stack varchar(2000),
	seq_id bigint NOT NULL,
	error_backtrace varchar(2000)
);


CREATE TABLE tm_cz.cz_job_master ( 
	job_id bigint NOT NULL,
	start_date timestamp,
	end_date timestamp,
	active varchar(1),
	time_elapsed_secs numeric(18,3) DEFAULT 0,
	build_id bigint,
	session_id bigint,
	database_name varchar(50),
	job_status varchar(50),
	job_name varchar(500)
);

ALTER TABLE tm_cz.cz_job_master ADD CONSTRAINT cz_job_master_pk PRIMARY KEY (job_id);


CREATE TABLE tm_cz.annotation_deapp (
	gpl_id varchar(100),
	probe_id varchar(100),
	gene_symbol varchar(100),
	gene_id varchar(100),
	probeset_id bigint,
	organism varchar(200)
);

CREATE SEQUENCE tm_cz.cz_form_layout_seq;
   
CREATE TABLE "TM_CZ"."CZ_FORM_LAYOUT" 
   (	"FORM_LAYOUT_ID" numeric(22,0), 
	"FORM_KEY" varchar(50), 
	"FORM_COLUMN" varchar(50), 
	"DISPLAY_NAME" varchar(50), 
	"DATA_TYPE" varchar(50), 
	"SEQUENCE" numeric(22,0)
   );
   
     CREATE TABLE "TM_CZ"."MIGRATE_TABLES" 
	 ("DATA_TYPE" VARCHAR(50)
	 , "TABLE_OWNER" VARCHAR(50)
	 , "TABLE_NAME" VARCHAR(50)
	 , "STUDY_SPECIFIC" CHAR(1)
	 , "WHERE_CLAUSE" VARCHAR(2000)
	 , "INSERT_SEQ" INT4
	 , "STAGE_TABLE_NAME" varchar(100)
	 , "REBUILD_INDEX" CHAR(1)
	 , "DELETE_SEQ" INT4) ;
	 
create table tm_cz.probeset_deapp
(probeset_id bigint
,probeset	 varchar(100)
,organism	 varchar(200)
,platform	 varchar(100)
);
