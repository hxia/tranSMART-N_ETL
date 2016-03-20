/*************************************************************************
 * tranSMART - translational medicine data mart
 *
 * Copyright 2008-2012 Janssen Research & Development, LLC.
 *
 * This product includes software developed at Janssen Research & Development, LLC.
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License 
 * as published by the Free Software  * Foundation, either version 3 of the License, or (at your option) any later version, along with the following terms:
 * 1.	You may convey a work based on this program in accordance with section 5, provided that you retain the above notices.
 * 2.	You may convey verbatim copies of this program code as you receive it, in any medium, provided that you retain the above notices.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS    * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *
 ******************************************************************/


package com.recomdata.pipeline.annotation.entrez
import com.recomdata.pipeline.util.Util
import groovy.sql.Sql
import org.apache.log4j.Logger

//class NetezzaGeneInfo extends GeneInfo {
class NetezzaGeneInfo {

    private static final Logger log = Logger.getLogger(NetezzaGeneInfo)

//    Sql biomart, searchapp
//    String geneInfoTable, geneSynonymTable

    /**
     *  load Entrez genes and their synonyms into search_keyword table
     *
     * @param databaseType
     * @param sql
     * @param props
     */
    void loadSearchKeyword() {
        if (props.get("skip_search_keyword").toString().toLowerCase().equals("yes")) {
            log.info("Skip loading Entrez genes into SEARCH_KEYWORD ...")
        } else {

            log.info("Start loading Entrez genes into Netezza SEARCH_KEYWORD ...")

            String qry = """ insert into searchapp.SEARCH_KEYWORD (SEARCH_KEYWORD_ID, KEYWORD, BIO_DATA_ID, UNIQUE_ID, DATA_CATEGORY, DISPLAY_DATA_CATEGORY)
                             select next value for SEQ_SEARCH_DATA_ID, t.bio_marker_name, t.bio_marker_id, 'GENE:'||t.primary_external_id, 'GENE', 'Gene'
                             from (
                                 select distinct bio_marker_name, bio_marker_id, primary_external_id
                                 from biomart.bio_marker
                                 where bio_marker_id not in
                                         (select bio_data_id from searchapp.search_keyword
                                          where data_category='GENE' and bio_data_id is not null)
                             ) t
				         """
            searchapp.execute(qry)

            log.info("End loading Entrez genes into Netezza SEARCH_KEYWORD ...")
        }
    }


    /**
     * load Entrez genes and their synonyms into search_keyword_term table
     *
     * @param databaseType
     * @param sql
     * @param props
     */
    void loadSearchKeywordTerm() {
        if (props.get("skip_search_keyword_term").toString().toLowerCase().equals("yes")) {
            log.info("Skip loading Entrez genes and synonyms to SEARCH_KEYWORD_TERM ...")
        } else {

            log.info("Start loading Entrez genes and synonyms to PostgreSQL SEARCH_KEYWORD_TERM ...")

            // Entrez genes
            String qry = """ insert into search_keyword_term (SEARCH_KEYWORD_TERM_ID, KEYWORD_TERM, SEARCH_KEYWORD_ID, RANK,TERM_LENGTH)
							 select nextval('SEQ_SEARCH_DATA_ID'), upper(keyword), search_keyword_id, 1, length(keyword)
							 from search_keyword
							 where search_keyword_id not in
								  (select search_keyword_id from searchapp.search_keyword_term where rank=1)
						 """
            searchapp.execute(qry)

            // Entrez synonym
            String qrys = """ insert into search_keyword_term (SEARCH_KEYWORD_TERM_ID, KEYWORD_TERM, SEARCH_KEYWORD_ID, RANK,TERM_LENGTH)
                              select nextval('SEQ_SEARCH_DATA_ID'), t.keyword_term, t.search_keyword_id, t.rank, t.term_length
                              from (
                                  select upper(e.code) as keyword_term, s.search_keyword_id, 2 as rank, length(s.keyword) as term_length
                                  from search_keyword s, biomart.bio_data_ext_code e, biomart.bio_disease d
                                  where s.bio_data_id=e.bio_data_id and e.bio_data_id=d.bio_disease_id
                                  minus
                                  select keyword_term, search_keyword_id, rank, term_length
                                  from searchapp.search_keyword_term
                                  where rank=2
                              )  t
						 """
            searchapp.execute(qrys)

            log.info "End loading Entrez genes and synonyms to PostgreSQL SEARCH_KEYWORD_TERM ... "
        }
    }


    void loadBioMarker(String taxonomyId, String organism) {

        log.info "Start updating BIO_MARKER for $taxonomyId:$organism using Entrez data ..."

        String qry = """ insert into bio_marker(BIO_MARKER_ID, bio_marker_name, bio_marker_description, organism, primary_source_code,
								primary_external_id, bio_marker_type)
						 select next value for SEQ_BIO_DATA_ID, gene_symbol, gene_descr, ?, 'Entrez', gene_id, 'GENE'
						 from ${geneInfoTable}
						 where tax_id=? and gene_id not in
							 (select primary_external_id from bio_marker where upper(organism)=?) """

        biomart.execute(qry, [organism, taxonomyId, organism])

        log.info "End updating BIO_MARKER for $taxonomyId:$organism using Entrez data ..."
    }


    void loadBioDataUid(String taxonomyId, String organism) {

        log.info "Start loading BIO_DATA_UID using Entrez data ..."

        String qry = """ insert into bio_data_uid(bio_data_id, unique_id, bio_data_type)
								select bio_marker_id, 'GENE:'||primary_external_id, 'BIO_MARKER.GENE'
								from biomart.bio_marker where upper(organism)=?
								minus
								select bio_data_id, unique_id, bio_data_type
								from bio_data_uid """

        log.info "Start loading genes from $taxonomyId:$organism  ..."
        biomart.execute(qry, [organism])
        log.info "End loading genes from $taxonomyId:$organism  ..."

        log.info "End loading BIO_DATA_UID using Entrez data ..."
    }



    void loadBioDataExtCode(String taxonomyId, String organism) {

        log.info "Start loading Netezza/PostgreSQL BIO_DATA_EXT_CODE using Entrez's synonyms data ..."
        log.info "Taxonomy Id: $taxonomyId       Organism: $organism"

        String qry = """ insert into bio_data_ext_code(BIO_DATA_EXT_CODE_ID, bio_data_id, code, code_source, code_type, bio_data_type)
                         select next value for SEQ_BIO_DATA_ID, t.bio_data_id, t.code, t.code_source, t.code_type, t.bio_data_type
                         from (
								 select t2.bio_marker_id as bio_data_id, t1.gene_synonym as code, 'Alias' as code_source,
								        'SYNONYM' as code_type, 'BIO_MARKER.GENE' as bio_data_type
								 from ${geneSynonymTable} t1, bio_marker t2
								 where tax_id=? and t1.gene_id = t2.primary_external_id
									  and upper(t2.organism)=?
								 minus
								 select bio_data_id, code, code_source, code_type, bio_data_type
								 from bio_data_ext_code ) t"""

        log.info "Start loading synonyms for genes from $taxonomyId:$organism  ..."
        biomart.execute(qry, [taxonomyId, organism])
        log.info "End loading synonyms for genes from $taxonomyId:$organism  ..."

        log.info "End loading Netezza/PostgreSQL BIO_DATA_EXT_CODE using Entrez's synonyms data ..."
    }


    void loadGeneInfo(File geneInfo) {
        String nzload = props.get("nzload")
        String user = props.get("biomart_username")
        String password = props.get("biomart_password")
        String host = props.get("url").split(":")[2].toString().replaceAll("/") { "" }

        def command = "$nzload -u $user -pw $password -host \"$host\" -db transmart -t $geneInfoTable -delim \"\\t\" -outputDir \"c:/temp\" -df \"$geneInfo\""
        log.info "nzload command: " + command
        def proc = command.execute()
        proc.waitFor()
    }

    void loadGeneSynonym(File geneSynonym) {
        String nzload = props.get("nzload")
        String user = props.get("biomart_username")
        String password = props.get("biomart_password")
        String host = props.get("url").split(":")[2].toString().replaceAll("/") { "" }

        def command = "$nzload -u $user -pw $password -host \"$host\" -db transmart -t $geneSynonymTable -delim \"\\t\" -outputDir \"c:/temp\" -df \"$geneSynonym\""
        log.info "nzload command: " + command
        def proc = command.execute()
        proc.waitFor()
    }


    void createGeneInfoTable() {

        String currentSchema = Util.getNetezzaCurrentSchema(biomart)

        String qry = "select count(*) from information_schema.tables where lower(table_name)=? and TABLE_SCHEMA='$currentSchema'"
//        log.info qry

        if (biomart.firstRow(qry, [geneInfoTable])[0] > 0) {
            log.info "Drop Netezza table $geneInfoTable ..."
            qry = "drop table $geneInfoTable"
            biomart.execute(qry)
        }

        log.info "Start creating Netezza/PostgreSQL table $geneInfoTable ..."

        qry = """ create table $geneInfoTable (
						tax_id   int,
						gene_id   varchar(10),
						gene_symbol   varchar(200),
						gene_descr    varchar(4000)
				 ) """
        biomart.execute(qry)

        log.info "End creating Netezza/PostgreSQL table $geneInfoTable ..."
    }


    void createGeneSynonymTable() {
        String currentSchema = Util.getNetezzaCurrentSchema(biomart)
        String qry = "select count(*) from information_schema.tables where lower(table_name)=? and TABLE_SCHEMA='$currentSchema'"
        log.info qry

        if (biomart.firstRow(qry, [geneSynonymTable])[0] > 0) {
            log.info "Drop Netezza/PostgreSQL  table $geneSynonymTable ..."
            qry = "drop table $geneSynonymTable"
            biomart.execute(qry)
        }

        log.info "Start creating Netezza/PostgreSQL table $geneSynonymTable ..."

        qry = """ create table $geneSynonymTable (
								tax_id        int,
								gene_id       varchar(10),
								gene_symbol   varchar(200),
								gene_synonym       varchar(200)
						 ) """
        biomart.execute(qry)

        log.info "End creating Netezza/PostgreSQL table $geneSynonymTable ..."
    }

    /**
     *  get the current schema in PostgreSQL
     *
     * @param sql
     * @return the name of current schema
     */
    String getCurrentSchema(Sql sql) {
        return sql.firstRow("select current_schema")[0]
    }
}
