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

import groovy.sql.Sql
import org.apache.log4j.Logger

class OracleGeneInfo extends GeneInfo {

    private static final Logger log = Logger.getLogger(OracleGeneInfo)

    /**
     *  load Entrez genes and their synonyms into search_keyword table
     *
     * @param sql
     * @param props
     */
    void loadSearchKeyword() {

        String qry = """ insert into ${searchappSchemaName}.SEARCH_KEYWORD (KEYWORD, BIO_DATA_ID, UNIQUE_ID, DATA_CATEGORY, DISPLAY_DATA_CATEGORY)
                         select distinct bio_marker_name, bio_marker_id, 'GENE:'||primary_external_id, 'GENE', 'Gene'
                         from ${biomartSchemaName}.bio_marker
                         where bio_marker_id not in
                              (select bio_data_id from ${searchappSchemaName}.search_keyword
                               where data_category='GENE' and bio_data_id is not null)
				     """

        searchapp.execute(qry)
    }

    /**
     * load Entrez genes and their synonyms into search_keyword_term table
     *
     * @param databaseType
     * @param sql
     * @param props
     */
    void loadSearchKeywordTerm() {

        // Entrez genes
        String qry = """ insert into ${searchappSchemaName}.search_keyword_term (KEYWORD_TERM, SEARCH_KEYWORD_ID, RANK,TERM_LENGTH)
						 select upper(keyword), search_keyword_id, 1, length(keyword)
						 from ${searchappSchemaName}.search_keyword
						 where search_keyword_id not in
							(select search_keyword_id from ${searchappSchemaName}.search_keyword_term where rank=1)
					 """
        searchapp.execute(qry)

        // Entrez synonym
        String qrys = """ insert into ${searchappSchemaName}.search_keyword_term (KEYWORD_TERM, SEARCH_KEYWORD_ID, RANK,TERM_LENGTH)
						  select upper(e.code), s.search_keyword_id, 2, length(s.keyword)
						  from ${searchappSchemaName}.search_keyword s, ${biomartSchemaName}.bio_data_ext_code e, ${biomartSchemaName}.bio_marker m
						  where s.bio_data_id=e.bio_data_id and e.bio_data_id=m.bio_marker_id
                          minus
						  select keyword_term, search_keyword_id, rank, term_length
                          from ${searchappSchemaName}.search_keyword_term
                          where rank=2
						 """
        searchapp.execute(qrys)
    }

    /**
     * load Entrez genes into BIOMART.BIO_MARKER
     *
     * @param taxonomyId
     * @param organism
     */
    void loadBioMarker(String taxonomyId, String organism) {

        String qry = """ insert into ${biomartSchemaName}.bio_marker(bio_marker_name, bio_marker_description, organism, primary_source_code,
								primary_external_id, bio_marker_type)
						 select gene_symbol, gene_descr, ?, 'Entrez', to_char(gene_id), 'GENE'
						 from $currentSchema.$geneInfoTable
						 where tax_id=? and to_char(gene_id) not in
							 (select primary_external_id from ${biomartSchemaName}.bio_marker where upper(organism)=?) """

        biomart.execute(qry, [organism, taxonomyId, organism])
    }

    /**
     * load Entrez genes into BIO_DATA_UID
     *
     * @param taxonomyId
     * @param organism
     */
    void loadBioDataUid(String taxonomyId, String organism) {

        String qry = """ insert into ${biomartSchemaName}.bio_data_uid(bio_data_id, unique_id, bio_data_type)
								select bio_marker_id, 'GENE:'||primary_external_id, to_nchar('BIO_MARKER.GENE')
								from ${biomartSchemaName}.bio_marker where upper(organism)=?
								minus
								select bio_data_id, unique_id, bio_data_type
								from ${biomartSchemaName}.bio_data_uid """

        biomart.execute(qry, [organism])
    }

    /**
     *  load Entrez genes into BIO_DATA_EXT_CODE
     *
     * @param taxonomyId
     * @param organism
     */
    void loadBioDataExtCode(String taxonomyId, String organism) {

        String qry = """ insert into ${biomartSchemaName}.bio_data_ext_code(bio_data_id, code, code_source, code_type, bio_data_type)
								 select t2.bio_marker_id, t1.gene_synonym, 'Alias', 'SYNONYM', 'BIO_MARKER.GENE'
								 from ${currentSchema}.${geneSynonymTable} t1, bio_marker t2
								 where tax_id=? and to_char(t1.gene_id) = t2.primary_external_id
									  and upper(t2.organism)=?
								 minus
								 select bio_data_id, code, to_char(code_source), to_char(code_type), bio_data_type
								 from ${biomartSchemaName}.bio_data_ext_code """

        biomart.execute(qry, [taxonomyId, organism])
    }

    /**
     * load Entrez genes into $currentSchema.$geneInfoTable
     */
    void loadGeneInfo() {

        String qry = "insert into $currentSchema.$geneInfoTable (tax_id, gene_id, gene_symbol, gene_descr) values (?, ?, ?, ?)"

        if (entrezGene.size() > 0) {
            biomart.withTransaction {
                biomart.withBatch(100, qry, { stmt ->
                    entrezGene.eachLine {

                        String[] str = it.split(/\t/)
                        //println str[0] + "\t" + str[1] + "\t" + str[2] + "\t" + str[3]

                        stmt.addBatch([
                                str[0].trim(),
                                str[1].trim(),
                                str[2].trim(),
                                str[3].trim()
                        ])
                    }
                })
            }
        } else {
            log.error("Entrez gene $entrezGene file is empty.")
        }
    }

    /**
     * load Entrez synonyms into $currentSchema.$geneSynonymTable
     */
    void loadGeneSynonym() {

        String qry = "insert into $currentSchema.$geneSynonymTable (tax_id, gene_id, gene_symbol, gene_synonym) values (?, ?, ?, ?)"

        if (entrezSynonym.size() > 0) {
            biomart.withTransaction {
                biomart.withBatch(100, qry, { stmt ->
                    entrezSynonym.eachLine {

                        String[] str = it.split(/\t/)
                        //println str[0] + "\t" + str[1] + "\t" + str[2] + "\t" + str[3]

                        stmt.addBatch([
                                str[0].trim(),
                                str[1].trim(),
                                str[2].trim(),
                                str[3].trim()
                        ])
                    }
                })
            }
        } else {
            log.error("Entrez gene's synonym file $entrezSynonym file is empty.")
        }
    }

    /**
     * create the temp table: $currentSchema.$geneInfoTable
     */
    void createGeneInfoTable() {

        String qry = """ create table $currentSchema.$geneInfoTable (
                            tax_id   number(10,0),
                            gene_id   number(20,0),
                            gene_symbol   varchar2(200),
                            gene_descr    varchar2(4000)
				 ) """
        biomart.execute(qry)
    }

    /**
     * drop the temp table:
     */
    void dropGeneInfoTable() {

        String qry = "select count(1) from user_tables where table_name=upper(?)"
        if (biomart.firstRow(qry, [geneInfoTable])[0] > 0) {

            qry = "drop table $currentSchema.$geneInfoTable purge"
            biomart.execute(qry)
        }
    }

    /**
     * create the temp table:  $currentSchema.$geneSynonymTable
     */
    void createGeneSynonymTable() {

        String qry = """ create table $currentSchema.$geneSynonymTable (
								tax_id        number(10,0),
								gene_id       number(20,0),
								gene_symbol   varchar2(200),
								gene_synonym       varchar2(200)
						 ) """

        biomart.execute(qry)
    }

    /**
     * drop the temp table:  $currentSchema.$geneSynonymTable
     */
    void dropGeneSynonymTable() {

        String qry = "select count(1) from user_tables where table_name=upper(?)"
        if (biomart.firstRow(qry, [geneSynonymTable])[0] > 0) {

            qry = "drop table $currentSchema.$geneSynonymTable purge"
            biomart.execute(qry)
        }
    }

    /**
     *  get the current schema name from Oracle
     *
     * @param sql
     * @return the name of current schema
     */
    String getCurrentSchema(Sql sql) {
        return sql.firstRow("select user from dual")[0]
    }
}
