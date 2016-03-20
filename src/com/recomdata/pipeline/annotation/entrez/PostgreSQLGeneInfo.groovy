/*************************************************************************
 * tranSMART - translational medicine data mart
 *
 * Copyright 2015 ConvergeHEALTH by Deloitte
 *
 * This product includes software developed at ConvergeHEALTH by Deloitte.
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
import org.postgresql.copy.CopyManager
import org.postgresql.core.BaseConnection

import java.sql.Connection

class PostgreSQLGeneInfo extends GeneInfo {

    private static final Logger log = Logger.getLogger(PostgreSQLGeneInfo)

    /**
     *  load Entrez genes and their synonyms into search_keyword table
     */
    void loadSearchKeyword() {
        String qry = """ insert into """ + searchappSchemaName + """.SEARCH_KEYWORD (SEARCH_KEYWORD_ID, KEYWORD, BIO_DATA_ID, UNIQUE_ID, DATA_CATEGORY, DISPLAY_DATA_CATEGORY)
                             select nextval('""" + searchappSchemaName + """.seq_search_data_id'), t.bio_marker_name, t.bio_marker_id, 'GENE:'||t.primary_external_id, 'GENE', 'Gene'
                             from (
                                 select distinct bio_marker_name, bio_marker_id, primary_external_id
                                 from """ + biomartSchemaName + """.bio_marker
                                 where bio_marker_id not in
                                         (select bio_data_id from """ + searchappSchemaName + """.search_keyword
                                          where data_category='GENE' and bio_data_id is not null)
                             ) t
				         """

        searchapp.execute(qry)
    }

    /**
     * load Entrez genes and their synonyms into search_keyword_term table
     */
    void loadSearchKeywordTerm() {
        // Entrez genes
        String qry1 = """ insert into """ + searchappSchemaName + """.search_keyword_term (SEARCH_KEYWORD_TERM_ID, KEYWORD_TERM, SEARCH_KEYWORD_ID, RANK,TERM_LENGTH)
							 select nextval('""" + searchappSchemaName + """.seq_search_data_id'), upper(keyword), search_keyword_id, 1, length(keyword)
							 from """ + searchappSchemaName + """.search_keyword
							 where search_keyword_id not in
								  (select search_keyword_id from """ + searchappSchemaName + """.search_keyword_term where rank=1)
						 """
        searchapp.execute(qry1)

        // Entrez synonym
        String qry2 = """ insert into """ + searchappSchemaName + """.search_keyword_term (SEARCH_KEYWORD_TERM_ID, KEYWORD_TERM, SEARCH_KEYWORD_ID, RANK,TERM_LENGTH)
                              select nextval('""" + searchappSchemaName + """.seq_search_data_id'), t.keyword_term, t.search_keyword_id, t.rank, t.term_length
                              from (
                                  select upper(e.code) as keyword_term, s.search_keyword_id, 2 as rank, length(s.keyword) as term_length
                                  from """ + searchappSchemaName + """.search_keyword s, """ + biomartSchemaName + """.bio_data_ext_code e, """ + biomartSchemaName + """.bio_disease d
                                  where s.bio_data_id=e.bio_data_id and e.bio_data_id=d.bio_disease_id
                                  except
                                  select keyword_term, search_keyword_id, rank, term_length
                                  from """ + searchappSchemaName + """.search_keyword_term
                                  where rank=2
                              )  t
						 """
        searchapp.execute(qry2)
    }

    /**
     * load Entrez gene info into BIOMART.BIO_MARKER
     *
     * @param taxonomyId
     * @param organism
     */
    void loadBioMarker(String taxonomyId, String organism) {

        String biomartSchemaName = "biomart"
        String qry = """ insert into """ + biomartSchemaName + """.bio_marker(BIO_MARKER_ID, bio_marker_name, bio_marker_description, organism, primary_source_code,
								primary_external_id, bio_marker_type)
						 select nextval('""" + biomartSchemaName + """.seq_bio_data_id'), gene_symbol, gene_descr, ?, 'Entrez', gene_id, 'GENE'
						 from $currentSchema.$geneInfoTable
						 where tax_id=? and gene_id not in
							 (select primary_external_id from """ + biomartSchemaName + """.bio_marker where upper(organism)=?) """

        biomart.execute(qry, [organism, taxonomyId, organism])
    }

    /**
     *  load Entrez records into BIO_DATA_UID table
     *
     * @param taxonomyId
     * @param organism
     */
    void loadBioDataUid(String taxonomyId, String organism) {

        String qry = """ insert into bio_data_uid(bio_data_id, unique_id, bio_data_type)
								select bio_marker_id, 'GENE:'||primary_external_id, 'BIO_MARKER.GENE'
								from """ + biomartSchemaName + """.bio_marker where upper(organism)=?
								except
								select bio_data_id, unique_id, bio_data_type
								from """ + biomartSchemaName + """.bio_data_uid """

        biomart.execute(qry, [organism])
    }

    /**
     * add Entrez gene's synonymd into BIOMART.BIO_DATA_EXT_CODE
     *
     * @param taxonomyId
     * @param organism
     */
    void loadBioDataExtCode(String taxonomyId, String organism) {

        String qry = """ insert into bio_data_ext_code(BIO_DATA_EXT_CODE_ID, bio_data_id, code, code_source, code_type, bio_data_type)
                         select nextval('""" + biomartSchemaName + """.seq_bio_data_id'), t.bio_data_id, t.code,
                                'Alias' as code_source, 'SYNONYM' as code_type, 'BIO_MARKER.GENE' as bio_data_type
                         from (
								 select t2.bio_marker_id as bio_data_id, t1.gene_synonym as code
								 from $currentSchema.$geneSynonymTable t1, """ + biomartSchemaName + """.bio_marker t2
								 where tax_id=? and t1.gene_id = t2.primary_external_id and upper(t2.organism)=?
								 except
								 select bio_data_id, code
								 from """ + biomartSchemaName + """.bio_data_ext_code
								 where code_source = 'Alias' and code_type = 'SYNONYM' and bio_data_type = 'BIO_MARKER.GENE'
								 ) t"""

        biomart.execute(qry, [taxonomyId, organism])
    }

    /**
     * load Entrez gene info into a temp table using COPY command
     */
    void loadGeneInfo() {
        if (entrezGene.size() > 0) {
            Connection conn = Util.getConnection(props, databaseType, "biomart")
            CopyManager copyManager = new CopyManager((BaseConnection) conn);
            FileReader fileReader = new FileReader(entrezGene);
            copyManager.copyIn("COPY $currentSchema.$geneInfoTable FROM STDIN", fileReader);
        } else {
            log.error("Entrez Gene file is empty:" + entrezGene.toString())
        }
    }

    /**
     *  load Entrez gene synonym data into a temp table using COPY command
     */
    void loadGeneSynonym() {

        if (entrezSynonym.size() > 0) {
            Connection conn = Util.getConnection(props, databaseType, "biomart")
            CopyManager copyManager = new CopyManager((BaseConnection) conn);
            FileReader fileReader = new FileReader(entrezSynonym);
            copyManager.copyIn("COPY $currentSchema.$geneSynonymTable FROM STDIN", fileReader);
        } else {
            log.error("Entrez's gene synonym file is empty: " + entrezSynonym.toString())
        }
    }

    /**
     * create a temp table to store gene_info data
     */
    void createGeneInfoTable() {
        String qry = """ create table $currentSchema.$geneInfoTable (
						tax_id        varchar(10),
						gene_id       varchar(10),
						gene_symbol   varchar(200),
						gene_descr    varchar(4000)
				 ) """
        biomart.execute(qry)
    }

    /**
     * drop a temp table for storing gene_info data
     */
    void dropGeneInfoTable() {

        String qry = "drop table if exists $currentSchema.$geneInfoTable"
        biomart.execute(qry)
    }

    /**
     * create a temp table to store gene's synonym data
     */
    void createGeneSynonymTable() {
        String qry = """ create table $currentSchema.$geneSynonymTable (
								tax_id             varchar(10),
								gene_id            varchar(10),
								gene_symbol        varchar(200),
								gene_synonym       varchar(200)
						 ) """
        biomart.execute(qry)
    }

    /**
     * drop a temp table for storing gene's synonym data
     */
    void dropGeneSynonymTable() {

        String qry = "drop table if exists $currentSchema.$geneSynonymTable"
        biomart.execute(qry)
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
