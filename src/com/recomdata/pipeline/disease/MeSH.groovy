package com.recomdata.pipeline.disease

import com.recomdata.pipeline.util.Util

import groovy.sql.Sql
import org.apache.log4j.Logger
//import org.apache.log4j.BasicConfigurator
//import org.apache.log4j.Level

import org.apache.log4j.PropertyConfigurator

class MeSH {

    private static final Logger log = Logger.getLogger(MeSH)
    private static Properties props

    static main(args) {

        PropertyConfigurator.configure("conf/log4j.properties");

        log.info("Start loading property file loader.properties ...")
        Properties props = Util.loadConfiguration("conf/MeSH.properties");

        String databaseType = props.("url").split(":")[1].toString().toLowerCase()

        Sql biomart = Util.createSqlFromPropertyFile(props, "biomart")
        Sql searchapp = Util.createSqlFromPropertyFile(props, "searchapp")

        MeSH mesh = new MeSH()

        // create a temporary table for MeSH data
        if (props.get("skip_mesh_table").toString().toLowerCase().equals("yes")) {
            log.info "Skip creating temporary tables for MeSH data ..."
        } else {
            mesh.createTempTable(databaseType, biomart, props.get("mesh_table"), props.get("mesh_synonym_table"))
        }

        File input = new File(props.get("mesh_source"))
        File output = new File(input.getParent() + "/MeSH.tsv")
        File entry = new File(input.getParent() + "/MeSH_Entry.tsv")

        String meshTree = props.get("load_mesh_tree_node")

        mesh.readMeSH(input, output, entry, meshTree)
        mesh.loadMeSH(databaseType, biomart, output, props)
        mesh.loadMeSHSynonym(databaseType, biomart, entry, props)
        mesh.loadBioDisease(databaseType, biomart, props)
        mesh.loadBioDataExtCode(databaseType, biomart, props)
        mesh.loadSearchKeyword(databaseType, searchapp, props)
        mesh.loadSearchKeywordTerm(databaseType, searchapp, props)
    }

    /**
     *  extract MeSH terms and their synonyms based on MeSH tree code
     *
     * @param input
     * @param output
     * @param synonym
     * @param meshTree
     */
    void readMeSH(File input, File output, File synonym, String meshTree) {

        if (input.size() > 0) {
            log.info("Start processing MeSH file: ${input} ...")

            StringBuffer sbMeSH = new StringBuffer()
            StringBuffer entry = new StringBuffer()
            String mh = "", ui = "", entry1 = "", entry2 = "", mn = ""
            String[] treeNodes
            boolean isNeeded = false

            input.eachLine {
                if (it.indexOf("*NEWRECORD") == 0) {
                    mh = ""
                    ui = ""
                }
                if (it.indexOf("MH ") == 0) mh = it.split("=")[1].trim()
                if (it.indexOf("MN ") == 0) mn = it.split("=")[1].trim()

                if (meshTree.equals(null) || meshTree.trim().equals("")) {
                    isNeeded = true
                } else if (meshTree.indexOf(",")) {
                    treeNodes = meshTree.split(",")
                    treeNodes.each { tree ->
                        if (it.indexOf("MN = $tree") == 0) {
                            isNeeded = true
                        }
                    }
                } else {
                    if (it.indexOf("MN = $meshTree") == 0) {
                        isNeeded = true
                    }
                }

                if (it.indexOf("UI ") == 0) {
                    ui = it.split("=")[1].trim()
                    if (isNeeded && (mh.size() > 0) && (ui.size() > 0)) sbMeSH.append("$ui\t$mh\t$mn\n")
                    isNeeded = false
                }
                if (it.indexOf("ENTRY") == 0) {
                    entry1 = it.split("=")[1].trim()
                    if (entry1.indexOf("|") != -1) {
                        entry2 = entry1.split("\\|")[0].trim()
                        entry.append(mh + "\t" + entry2 + "\n")
                    } else {
                        entry.append(mh + "\t" + entry1 + "\n")
                    }
                }
            }

            if (output.size() > 0) {
                output.delete()
                output.createNewFile()
            }
            output.append(sbMeSH.toString())

            if (synonym.size() > 0) {
                synonym.delete()
                synonym.createNewFile()
            }
            synonym.append(entry.toString())
        } else {
            log.error("File ${input} is empty ...")
        }
    }

    /**
     * load MeSH term's synonyms into temp table
     *
     * @param databaseType
     * @param sql
     * @param meshEntry
     * @param props
     */
    void loadMeSHSynonym(String databaseType, Sql sql, File meshEntry, Properties props) {
        String MeSHSynonymTable = props.get("mesh_synonym_table")
        if (databaseType.equals("oracle")) {
            loadOracleMeSHSynonym(sql, meshEntry, MeSHSynonymTable)
        } else if (databaseType.equals("netezza")) {
            loadNetezzaMeSHSynonym(sql, meshEntry, MeSHSynonymTable, props)
        } else if (databaseType.equals("postgresql")) {
            loadPostgreSQLMeSHSynonym(sql, meshEntry, MeSHSynonymTable)
        } else if (databaseType.equals("db2")) {
            //loadDB2MeSHSynonym(sql, meshEntry, MeSHSynonymTable)
        } else {

        }
    }

    /**
     * load MeSH terms into temp table
     *
     * @param databaseType
     * @param sql
     * @param mesh
     * @param props
     */
    void loadMeSH(String databaseType, Sql sql, File mesh, Properties props) {
        String MeSHTable = props.get("mesh_table")
        if (databaseType.equals("oracle")) {
            loadOracleMeSH(sql, mesh, MeSHTable)
        } else if (databaseType.equals("netezza")) {
            loadNetezzaMeSH(sql, mesh, MeSHTable, props)
        } else if (databaseType.equals("postgresql")) {
            loadPostgreSQLMeSH(sql, mesh, MeSHTable)
        } else if (databaseType.equals("db2")) {
            //loadDB2MeSH(sql, mesh, MeSHTable)
        } else {

        }
    }

    /**
     * load MeSH disease terms into bio_disease
     *
     * @param databaseType
     * @param sql
     * @param props
     */
    void loadBioDisease(String databaseType, Sql sql, Properties props) {
        if (databaseType.equals("oracle")) {
            loadOracleBioDisease(sql, props)
        } else if (databaseType.equals("netezza")) {
            loadNetezzaBioDisease(sql, props)
        } else if (databaseType.equals("postgresql")) {
            loadPostgreSQLBioDisease(sql, props)
        } else if (databaseType.equals("db2")) {
            //  loadDB2BioDisease(sql, props)
        } else {
            log.info "Database support for $databaseType will be added soon ... "
        }
    }

    /**
     * load MeSH disease terms into bio_disease @ Oracle
     *
     * @param sql
     * @param props
     */
    void loadOracleBioDisease(Sql sql, Properties props) {

        String MeSHTable = props.get("mesh_table")

        if (props.get("skip_bio_disease").toString().toLowerCase().equals("yes")) {
            log.info("Skip loading MeSH data from ${MeSHTable} to BIO_DISEASE ...")
        } else {
            log.info("Start loading MeSH data from ${MeSHTable} to BIO_DISEASE ...")

            String qry = """ insert into bio_disease (disease, mesh_code, prefered_name)
						     select mh, ui, mh from $MeSHTable
						     where ui not in (select mesh_code from bio_disease where mesh_code is not null)"""
            sql.execute(qry)

            log.info("End loading MeSH data from ${MeSHTable} to BIO_DISEASE ...")
        }
    }

    /**
     * load MeSH disease terms into bio_disease @ Netezza
     *
     * @param sql
     * @param props
     */
    void loadNetezzaBioDisease(Sql sql, Properties props) {

        String MeSHTable = props.get("mesh_table")

        if (props.get("skip_bio_disease").toString().toLowerCase().equals("yes")) {
            log.info("Skip loading MeSH data from ${MeSHTable} to BIO_DISEASE ...")
        } else {
            log.info("Start loading MeSH data from ${MeSHTable} to BIO_DISEASE ...")

            String qry = """ insert into biomart.bio_disease (bio_disease_id, disease, mesh_code, prefered_name)
						     select next value for SEQ_BIO_DATA_ID, mh, ui, mh from $MeSHTable
						     where ui not in (select mesh_code from bio_disease where mesh_code is not null)"""
            sql.execute(qry)

            log.info("End loading MeSH data from ${MeSHTable} to BIO_DISEASE ...")
        }
    }

    /**
     * load MeSH disease terms into bio_disease @ PostgreSQL
     *
     * @param sql
     * @param props
     */
    void loadPostgreSQLBioDisease(Sql sql, Properties props) {

        String MeSHTable = props.get("mesh_table")

        if (props.get("skip_bio_disease").toString().toLowerCase().equals("yes")) {
            log.info("Skip loading MeSH data from ${MeSHTable} to BIO_DISEASE ...")
        } else {
            log.info("Start loading MeSH data from ${MeSHTable} to BIO_DISEASE ...")

            String qry = """ insert into bio_disease (bio_disease_id, disease, mesh_code, prefered_name)
						     select nextval('SEQ_BIO_DATA_ID'), mh, ui, mh from $MeSHTable
						     where ui not in (select mesh_code from bio_disease where mesh_code is not null)"""
            sql.execute(qry)

            log.info("End loading MeSH data from ${MeSHTable} to BIO_DISEASE ...")
        }
    }

    /**
     *  load MeSH disease terms into bio_data_ext_coe table
     *
     * @param databaseType
     * @param sql
     * @param props
     */
    void loadBioDataExtCode(String databaseType, Sql sql, Properties props) {
        if (databaseType.equals("oracle")) {
            loadOracleBioDataExtCode(sql, props)
        } else if (databaseType.equals("netezza")) {
            loadNetezzaBioDataExtCode(sql, props)
        } else if (databaseType.equals("postgresql")) {
            loadPostgreSQLBioDataExtCode(sql, props)
        } else if (databaseType.equals("db2")) {
            //  loadDB2BioDataExtCode(sql, props)
        } else {
            log.info "Database support for $databaseType will be added soon ... "
        }
    }

    /**
     * load MeSH disease terms into bio_data_ext_code table @ Oracle
     *
     * @param sql
     * @param props
     */
    void loadOracleBioDataExtCode(Sql sql, Properties props) {

        String MeSHSynonymTable = props.get("mesh_synonym_table")

        if (props.get("skip_bio_data_ext_code").toString().toLowerCase().equals("yes")) {
            log.info("Skip loading MeSH data from ${MeSHSynonymTable} to BIO_DATA_EXT_CODE ...")
        } else {
            log.info("Start loading MeSH data from ${MeSHSynonymTable} to BIO_DATA_EXT_CODE ...")

            String qry = """ insert into bio_data_ext_code(bio_data_id, code, code_source, code_type, bio_data_type)
							 select d.bio_disease_id, m.entry, 'Alias', 'SYNONYM', 'BIO_DISEASE' 
                             from bio_disease d, $MeSHSynonymTable m
							 where to_char(d.disease) = m.mh and d.disease is not null
                             minus
                             select bio_data_id, code, 'Alias', 'SYNONYM', 'BIO_DISEASE'
                             from bio_data_ext_code"""
            sql.execute(qry)

            log.info("End loading MeSH data from ${MeSHSynonymTable} to BIO_DATA_EXT_CODE ...")
        }
    }

    /**
     * load MeSH disease terms into bio_data_ext_code table @ Netezza
     *
     * @param sql
     * @param props
     */
    void loadNetezzaBioDataExtCode(Sql sql, Properties props) {

        String MeSHSynonymTable = props.get("mesh_synonym_table")

        if (props.get("skip_bio_data_ext_code").toString().toLowerCase().equals("yes")) {
            log.info("Skip loading MeSH data from ${MeSHSynonymTable} to BIO_DATA_EXT_CODE ...")
        } else {
            log.info("Start loading MeSH data from ${MeSHSynonymTable} to BIO_DATA_EXT_CODE ...")

            String qry = """ insert into biomart.bio_data_ext_code(BIO_DATA_EXT_CODE_ID, bio_data_id, code, code_source, code_type, bio_data_type)
                             select next value for SEQ_BIO_DATA_ID, t.bio_data_id, t.code, 'Alias', 'SYNONYM', 'BIO_DISEASE'
                             from (
                                 select d.bio_disease_id as bio_data_id, m.entry as code
                                 from biomart.bio_disease d, $MeSHSynonymTable m
                                 where lower(d.disease) = lower(m.mh) and d.disease is not null
                                 minus
                                 select bio_data_id, code from biomart.bio_data_ext_code
                             ) t"""
            sql.execute(qry)

            log.info("End loading MeSH data from ${MeSHSynonymTable} to BIO_DATA_EXT_CODE ...")
        }
    }

    /**
     * load MeSH disease terms into bio_data_ext_code table @ PostgreSQL
     *
     * @param sql
     * @param props
     */
    void loadPostgreSQLBioDataExtCode(Sql sql, Properties props) {

        String MeSHSynonymTable = props.get("mesh_synonym_table")

        if (props.get("skip_bio_data_ext_code").toString().toLowerCase().equals("yes")) {
            log.info("Skip loading MeSH data from ${MeSHSynonymTable} to BIO_DATA_EXT_CODE ...")
        } else {
            log.info("Start loading MeSH data from ${MeSHSynonymTable} to BIO_DATA_EXT_CODE ...")

            String qry = """ insert into bio_data_ext_code(BIO_DATA_EXT_CODE_ID, bio_data_id, code, code_source, code_type, bio_data_type)
                             select nextval('SEQ_BIO_DATA_ID'), t.bio_data_id, t.code, 'Alias', 'SYNONYM', 'BIO_DISEASE'
                             from (
                                 select d.bio_disease_id as bio_data_id, m.entry as code
                                 from bio_disease d, $MeSHSynonymTable m
                                 where lower(d.disease) = lower(m.mh) and d.disease is not null
                                 minus
                                 select bio_data_id, code from bio_data_ext_code
                             ) t"""

            sql.execute(qry)

            log.info("End loading MeSH data from ${MeSHSynonymTable} to BIO_DATA_EXT_CODE ...")
        }
    }

    /**
     *  load MeSH terms and their synonyms into search_keyword table
     *
     * @param databaseType
     * @param sql
     * @param props
     */
    void loadSearchKeyword(String databaseType, Sql sql, Properties props) {
        if (databaseType.equals("oracle")) {
            loadOracleSearchKeyword(sql, props)
        } else if (databaseType.equals("netezza")) {
            loadNetezzaSearchKeyword(sql, props)
        } else if (databaseType.equals("postgresql")) {
            //loadPostgreSQLSearchKeyword(sql, props)
        } else if (databaseType.equals("db2")) {
            //  loadDB2SearchKeyword(sql, props)
        } else {
            log.info "Database support for $databaseType will be added soon ... "
        }
    }

    /**
     * load MeSH terms and their synonyms into search_keyword table @ Oracle
     *
     * @param sql
     * @param props
     */
    void loadOracleSearchKeyword(Sql sql, Properties props) {

        String MeSHTable = props.get("mesh_table")

        if (props.get("skip_search_keyword").toString().toLowerCase().equals("yes")) {
            log.info("Skip loading MeSH data from ${MeSHTable} to SEARCH_KEYWORD ...")
        } else {
            log.info("Start loading MeSH data from ${MeSHTable} to SEARCH_KEYWORD ...")

            String qry = """ insert into SEARCH_KEYWORD (KEYWORD, BIO_DATA_ID, UNIQUE_ID, DATA_CATEGORY, DISPLAY_DATA_CATEGORY)
					   	     select distinct t1.mh, t2.bio_disease_id, 'DIS:'||t1.ui, 'DISEASE', 'Disease'  
                             from biomart.$MeSHTable t1, biomart.bio_disease t2
						     where t1.ui=to_char(t2.mesh_code)  
                                 and t2.bio_disease_id not in 
                                     (select bio_data_id from search_keyword 
                                      where data_category='DISEASE' and bio_data_id is not null)
				         """
            sql.execute(qry)

            log.info("End loading MeSH data from ${MeSHTable} to SEARCH_KEYWORD ...")
        }
    }

    /**
     * load MeSH terms and their synonyms into search_keyword table @ Netezza
     *
     * @param sql
     * @param props
     */
    void loadNetezzaSearchKeyword(Sql sql, Properties props) {

        String MeSHTable = props.get("mesh_table")

        if (props.get("skip_search_keyword").toString().toLowerCase().equals("yes")) {
            log.info("Skip loading MeSH data from ${MeSHTable} to SEARCH_KEYWORD ...")
        } else {
            log.info("Start loading MeSH data from ${MeSHTable} to SEARCH_KEYWORD ...")

            String qry = """ insert into searchapp.SEARCH_KEYWORD (SEARCH_KEYWORD_ID, KEYWORD, BIO_DATA_ID, UNIQUE_ID, DATA_CATEGORY, DISPLAY_DATA_CATEGORY)
                             select next value for SEQ_SEARCH_DATA_ID, t.mh, t.bio_disease_id, 'DIS:'||t.ui, 'DISEASE', 'Disease'
                             from (
                                 select distinct t1.mh, t2.bio_disease_id, t1.ui
                                 from $MeSHTable t1, biomart.bio_disease t2
                                 where lower(t1.ui)=lower(t2.mesh_code)
                                     and t2.bio_disease_id not in
                                         (select bio_data_id from searchapp.search_keyword
                                          where data_category='DISEASE' and bio_data_id is not null)
                             ) t
				         """
            sql.execute(qry)

            log.info("End loading MeSH data from ${MeSHTable} to SEARCH_KEYWORD ...")
        }
    }

    /**
     * load MeSH terms and their synonyms into search_keyword table @ PostgreSQL
     *
     * @param sql
     * @param props
     */
    void loadPostgreSQLSearchKeyword(Sql sql, Properties props) {

        String MeSHTable = props.get("mesh_table")

        if (props.get("skip_search_keyword").toString().toLowerCase().equals("yes")) {
            log.info("Skip loading MeSH data from ${MeSHTable} to SEARCH_KEYWORD ...")
        } else {
            log.info("Start loading MeSH data from ${MeSHTable} to SEARCH_KEYWORD ...")

            String qry = """ insert into searchapp.SEARCH_KEYWORD (SEARCH_KEYWORD_ID, KEYWORD, BIO_DATA_ID, UNIQUE_ID, DATA_CATEGORY, DISPLAY_DATA_CATEGORY)
                             select nextval('SEQ_SEARCH_DATA_ID'), t.mh, t.bio_disease_id, 'DIS:'||t.ui, 'DISEASE', 'Disease'
                             from (
                                 select distinct t1.mh, t2.bio_disease_id, t1.ui
                                 from $MeSHTable t1, biomart.bio_disease t2
                                 where lower(t1.ui)=lower(t2.mesh_code)
                                     and t2.bio_disease_id not in
                                         (select bio_data_id from searchapp.search_keyword
                                          where data_category='DISEASE' and bio_data_id is not null)
                             ) t
				         """
            sql.execute(qry)

            log.info("End loading MeSH data from ${MeSHTable} to SEARCH_KEYWORD ...")
        }
    }

    /**
     * load MeSH terms and their synonyms into search_keyword_term table
     *
     * @param databaseType
     * @param sql
     * @param props
     */
    void loadSearchKeywordTerm(String databaseType, Sql sql, Properties props) {
        if (databaseType.equals("oracle")) {
            loadOracleSearchKeywordTerm(sql, props)
        } else if (databaseType.equals("netezza")) {
            loadNetezzaSearchKeywordTerm(sql, props)
        } else if (databaseType.equals("postgresql")) {
            //loadPostgreSQLSearchKeywordTerm(sql, props)
        } else if (databaseType.equals("db2")) {
            //  loadDB2SearchKeywordTerm(sql, props)
        } else {
            log.info "Database support for $databaseType will be added soon ... "
        }
    }

    /**
     *  load MeSH terms and their synonyms into search_keyword_term table @ Oracle
     *
     * @param sql
     * @param props
     */
    void loadOracleSearchKeywordTerm(Sql sql, Properties props) {

        String MeSHTable = props.get("mesh_table")
        String MeSHSynonymTable = props.get("mesh_synonym_table")

        if (props.get("skip_search_keyword_term").toString().toLowerCase().equals("yes")) {
            log.info("Skip loading MeSH data from ${MeSHTable} and ${MeSHSynonymTable} to SEARCH_KEYWORD_TERM ...")
        } else {
            log.info("Start loading MeSH data from ${MeSHTable} and ${MeSHSynonymTable} to SEARCH_KEYWORD_TERM ...")

            // MeSH Disease Heading
            String qry = """ insert into search_keyword_term (KEYWORD_TERM, SEARCH_KEYWORD_ID, RANK,TERM_LENGTH)
							 select upper(keyword), search_keyword_id, 1, length(keyword)
							 from search_keyword
							 where search_keyword_id not in
								  (select search_keyword_id from searchapp.search_keyword_term where rank=1)
						 """
            sql.execute(qry)

            // MeSH Disease Entry/Synonym
            String qrys = """ insert into search_keyword_term (KEYWORD_TERM, SEARCH_KEYWORD_ID, RANK,TERM_LENGTH)
							  select upper(e.code), s.search_keyword_id, 2, length(s.keyword)
							  from search_keyword s, biomart.bio_data_ext_code e, biomart.bio_disease d
							  where s.bio_data_id=e.bio_data_id and e.bio_data_id=d.bio_disease_id
                              minus
							  select keyword_term, search_keyword_id, rank, term_length 
                              from searchapp.search_keyword_term 
                              where rank=2
						 """
            sql.execute(qrys)

            log.info "End loading MeSH data from ${MeSHTable} and ${MeSHSynonymTable} to SEARCH_KEYWORD_TERM ... "
        }
    }

    /**
     *  load MeSH terms and their synonyms into search_keyword_term table @ Netezza
     *
     * @param sql
     * @param props
     */
    void loadNetezzaSearchKeywordTerm(Sql sql, Properties props) {

        String MeSHTable = props.get("mesh_table")
        String MeSHSynonymTable = props.get("mesh_synonym_table")

        if (props.get("skip_search_keyword_term").toString().toLowerCase().equals("yes")) {
            log.info("Skip loading MeSH data from ${MeSHTable} and ${MeSHSynonymTable} to SEARCH_KEYWORD_TERM ...")
        } else {
            log.info("Start loading MeSH data from ${MeSHTable} and ${MeSHSynonymTable} to SEARCH_KEYWORD_TERM ...")

            // MeSH Disease Heading
            String qry = """ insert into searchapp.search_keyword_term (SEARCH_KEYWORD_TERM_ID, KEYWORD_TERM, SEARCH_KEYWORD_ID, RANK,TERM_LENGTH)
							 select next value for SEQ_SEARCH_DATA_ID, upper(keyword), search_keyword_id, 1, length(keyword)
							 from searchapp.search_keyword
							 where search_keyword_id not in
								  (select search_keyword_id from searchapp.search_keyword_term where rank=1)
						 """
            sql.execute(qry)

            // MeSH Disease Entry/Synonym
            String qrys = """ insert into searchapp.search_keyword_term (SEARCH_KEYWORD_TERM_ID, KEYWORD_TERM, SEARCH_KEYWORD_ID, RANK, TERM_LENGTH)
							  select next value for SEQ_SEARCH_DATA_ID, t.keyword_term, t.search_keyword_id, t.rank, t.term_length
							  from (
                                  select upper(e.code) as keyword_term, s.search_keyword_id, 2 as rank, length(s.keyword) as term_length
                                  from searchapp.search_keyword s, biomart.bio_data_ext_code e, biomart.bio_disease d
                                  where s.bio_data_id=e.bio_data_id and e.bio_data_id=d.bio_disease_id
                                  minus
                                  select keyword_term, search_keyword_id, rank, term_length
                                  from searchapp.search_keyword_term
                                  where rank=2
                              ) t
						 """
            sql.execute(qrys)

            log.info "End loading MeSH data from ${MeSHTable} and ${MeSHSynonymTable} to SEARCH_KEYWORD_TERM ... "
        }
    }

    /**
     *  load MeSH term's synonyms into temp table @ PostgreSQL
     *
     * @param sql
     * @param meshEntry
     * @param MeSHSynonymTable
     */
    void loadPostgreSQLMeSHSynonym(Sql sql, File meshEntry, String MeSHSynonymTable) {
        loadOracleMeSHSynonym(sql, meshEntry, MeSHSynonymTable)
    }

    /**
     *  load MeSH term's synonyms into temp table @ Oracle
     *
     * @param biomart
     * @param meshEntry
     * @param MeSHSynonymTable
     */
    void loadOracleMeSHSynonym(Sql sql, File meshEntry, String MeSHSynonymTable) {

        String qry = "insert into $MeSHSynonymTable (mh, entry) values(?, ?)"

        if (meshEntry.size() > 0) {
            log.info("Start loading MeSH synonym file: ${meshEntry} into ${MeSHSynonymTable} ...")

            sql.withTransaction {
                sql.withBatch(qry, { stmt ->
                    meshEntry.eachLine {
                        String[] str = it.split("\t")
                        stmt.addBatch([str[0], str[1]])
                    }
                })
            }

        } else {
            log.error("File ${meshEntry} is empty ...")
        }
    }

    /**
     *  load MeSH term's synonyms into temp table @ Netezza
     *
     * @param sql
     * @param meshEntry
     * @param MeSHSynonymTable
     * @param props
     */
    void loadNetezzaMeSHSynonym(Sql sql, File meshEntry, String MeSHSynonymTable, Properties props) {
        String nzload = props.get("nzload")
        String user = props.get("biomart_username")
        String password = props.get("biomart_password")
        String host = props.get("url").split(":")[2].toString().replaceAll("/") { "" }
        String databaseName = Util.getDatabaseName(props)

        def command = "$nzload -u $user -pw $password -host \"$host\" -db $databaseName -t $MeSHSynonymTable -delim \"\\t\" -outputDir \"c:/temp\" -df \"$meshEntry\""
        log.info "nzload command: " + command
        def proc = command.execute()
        proc.waitFor()
    }

    /**
     * load MeSH terms into Netezza temp table
     *
     * @param sql
     * @param mesh
     * @param MeSHTable
     */
    void loadNetezzaMeSH(Sql sql, File mesh, String MeSHTable, Properties props) {
        String nzload = props.get("nzload")
        String user = props.get("biomart_username")
        String password = props.get("biomart_password")
        String host = props.get("url").split(":")[2].toString().replaceAll("/") { "" }
        String databaseName = Util.getDatabaseName(props)

        def command = "$nzload -u $user -pw $password -host \"$host\" -db $databaseName -t $MeSHTable -delim \"\\t\" -outputDir \"c:/temp\" -df \"$mesh\""
        log.info "nzload command: " + command
        def proc = command.execute()
        proc.waitFor()
    }

    /**
     * load MeSH terms into PostgreSQL temp table
     *
     * @param sql
     * @param mesh
     * @param MeSHTable
     */
    void loadPostgreSQLMeSH(Sql sql, File mesh, String MeSHTable) {
        loadOracleMeSH(sql, mesh, MeSHTable)
    }

    /**
     * load MeSH terms into Oracle temp table
     *
     * @param sql
     * @param mesh
     * @param MeSHTable
     */
    void loadOracleMeSH(Sql sql, File mesh, String MeSHTable) {

        String qry = "insert into $MeSHTable (ui, mh, mn) values(?, ?, ?)"

        if (mesh.size() > 0) {
            log.info("Start loading MeSH file: ${mesh} into ${MeSHTable} ...")

            sql.withTransaction {
                sql.withBatch(qry, { stmt ->
                    mesh.eachLine {
                        String[] str = it.split("\t")
                        if(str.size()==3) stmt.addBatch([str[0], str[1], str[2]])
                        else log.info "Invalid line: $it"
                    }
                })
            }

        } else {
            log.error("File ${mesh} is empty ...")
        }
    }

    /**
     *  create temp tables to hold MeSH terms and synonyms
     *
     * @param databaseType
     * @param sql
     * @param MeSHTable
     */
    void createTempTable(String databaseType, Sql sql, String MeSHTable, String MeSHSynonymTable) {
        if (databaseType.equals("oracle")) {
//        if (databaseType == "oracle") {
            createOracleMeSHTable(sql, MeSHTable)
            createOracleMeSHSynonymTable(sql, MeSHSynonymTable)
        } else if (databaseType.equals("netezza")) {
            createNetezzaMeSHTable(sql, MeSHTable)
            createNetezzaMeSHSynonymTable(sql, MeSHSynonymTable)
        } else if (databaseType.equals("postgresql")) {
            createPostgreSQLMeSHTable(sql, MeSHTable)
            createPostgreSQLMeSHSynonymTable(sql, MeSHSynonymTable)
        } else if (databaseType.equals("db2")) {
            //createDB2MeSHTable(sql, MeSHTable)
            //createDB2MeSHSynonymTable(sql, MeSHSynonymTable)
        } else {

        }
    }

    /**
     * create temp table for MeSH @ Oracle
     *
     * @param sql
     * @param MeSHTable
     */
    void createOracleMeSHTable(Sql sql, String MeSHTable) {
        log.info "Start creating Oracle table: ${MeSHTable}"

        String qry = """ create table ${MeSHTable} (
									UI  varchar2(20) primary key,
									MH	varchar2(200),
									MN  varchar2(200)
								 )
							"""

        String qry1 = "select count(*) from user_tables where table_name=?"
        if (sql.firstRow(qry1, [MeSHTable.toUpperCase()])[0] > 0) {
            log.info "Drop table ${MeSHTable} first ... "
            qry1 = "drop table ${MeSHTable} purge"
            sql.execute(qry1)
        }

        sql.execute(qry)

        log.info "End creating Oracle table: ${MeSHTable}"
    }

    /**
     *   create temp table for MeSH Synonyms @ Oracle
     *
     * @param sql
     * @param MeSHSynonymTable
     */
    void createOracleMeSHSynonymTable(Sql sql, String MeSHSynonymTable) {

        log.info "Start creating Oracle table: ${MeSHSynonymTable}"

        String qry = """ create table ${MeSHSynonymTable} (
							MH      varchar2(200),
							ENTRY	varchar2(200)
						 )
					"""

        String qry1 = "select count(*) from user_tables where table_name=?"
        if (sql.firstRow(qry1, [
                MeSHSynonymTable.toUpperCase()
        ])[0] > 0) {
            log.info "Drop table ${MeSHSynonymTable} first ... "
            qry1 = "drop table ${MeSHSynonymTable} purge"
            sql.execute(qry1)
        }

        sql.execute(qry)

        log.info "End creating Oracle table: ${MeSHSynonymTable}"
    }

    /**
     *  create temp table for MeSH terms @ PostgreSQL
     *
     * @param sql
     * @param MeSHTable
     */
    void createPostgreSQLMeSHTable(Sql sql, String MeSHTable) {
        createNetezzaMeSHTable(sql, MeSHTable)
    }

    /**
     *  create temp table for MeSH terms @ Netezza
     *
     * @param sql
     * @param MeSHTable
     */
    void createNetezzaMeSHTable(Sql sql, String MeSHTable) {

        // get current schema
        String currentSchema = Util.getNetezzaCurrentSchema(sql)

        log.info "Start creating Netezza/PostgreSQL table: ${MeSHTable}"

        String qry = """ create table ${MeSHTable} (
									UI  varchar(20) primary key,
									MH	varchar(200),
									MN  varchar(200)
								 )
							"""

        String qry1 = "select count(*) from information_schema.tables where table_name=? and TABLE_SCHEMA='$currentSchema'"
        if (sql.firstRow(qry1, [
                MeSHTable.toUpperCase()
        ])[0] > 0) {
            log.info "Drop table ${MeSHTable} first ..."
            qry1 = "drop table ${MeSHTable}"
            sql.execute(qry1)
        }

        sql.execute(qry)

        log.info "End creating Netezza/PostgreSQL table: ${MeSHTable}"
    }

    /**
     *  create temp table for MeSH synonyms @ PostgreSQL
     *
     * @param sql
     * @param MeSHSynonymTable
     */
    void createPostgreSQLMeSHSynonymTable(Sql sql, String MeSHSynonymTable) {
        createNetezzaMeSHSynonymTable(sql, MeSHSynonymTable)
    }

    /**
     *  create temp table for MeSH synonyms @ Netezza
     *
     * @param sql
     * @param MeSHSynonymTable
     */
    void createNetezzaMeSHSynonymTable(Sql sql, String MeSHSynonymTable) {

        // get current schema
        String currentSchema = Util.getNetezzaCurrentSchema(sql)

        log.info "Start creating Netezza/PostgreSQL table: ${MeSHSynonymTable}"

        String qry = """ create table ${MeSHSynonymTable} (
							MH      varchar(200),
							ENTRY	varchar(200)
						 )
					"""

        String qry1 = "select count(*) from information_schema.tables where table_name=? and TABLE_SCHEMA='$currentSchema'"
        if (sql.firstRow(qry1, [
                MeSHSynonymTable.toUpperCase()
        ])[0] > 0) {
            log.info "Drop table ${MeSHSynonymTable} first ..."
            qry1 = "drop table ${MeSHSynonymTable}"
            sql.execute(qry1)
        }

        sql.execute(qry)
        log.info "End creating Netezza/PostgreSQL table: ${MeSHSynonymTable}"
    }

}