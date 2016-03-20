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


package com.recomdata.pipeline.pathway

import com.recomdata.pipeline.transmart.*
import com.recomdata.pipeline.util.Util
import groovy.sql.Sql
import org.apache.log4j.Logger
import org.apache.log4j.PropertyConfigurator

class GeneOntology {

    private static final Logger log = Logger.getLogger(GeneOntology)

    Sql biomart, searchapp, deapp

    static main(args) {

        PropertyConfigurator.configure("conf/log4j.properties");

        log.info("Start loading property file ...")
        Properties props = Util.loadConfiguration("conf/loader.properties");
        String databaseType = Util.getDatabaseType(props)

        Sql deapp = Util.createSqlFromPropertyFile(props, "deapp")
        Sql biomart = Util.createSqlFromPropertyFile(props, "biomart")
        Sql searchapp = Util.createSqlFromPropertyFile(props, "searchapp")

        GeneOntology geneOntology = new GeneOntology()

        geneOntology.setSearchapp(searchapp)
        geneOntology.setBiomart(biomart)
        geneOntology.setDeapp(deapp)
        geneOntology.createPathwayTable(databaseType, props)
//        geneOntology.createPathwayDataTable(databaseType, props) //.get("pathway_data_table"))

        //Map humanGeneId = [:], mouseGeneId = [:], ratGeneId = [:]

        // Homo sapiens
        //humanGeneId = geneOntology.getGeneId(biomart, "9606", props.get("gene_info_table"))

        // Mus musculus
        //mouseGeneId = geneOntology.getGeneId(biomart, "10090", props.get("gene_info_table"))

        // Rattus norvegicus
        //ratGeneId = geneOntology.getGeneId(biomart, "10116", props.get("gene_info_table"))

        //println humanGeneId.size() + "\t" + mouseGeneId.size() + "\t" + ratGeneId.size()

        // process Gene Ontology data

        File goInput = new File(props.get("gene_ontology_source"))
        File goOutput = new File(goInput.getParent() + "/gene_ontology.tsv")
        geneOntology.readGeneOntology(goInput, goOutput)
        geneOntology.loadGeneOntology(databaseType, goOutput, props)

        // process Gene Association data for Homo sapiens
        File goahInput = new File(props.get("gene_association_human"))
        File goahOutput = new File(goahInput.getParent() + "/goa_human.tsv")
        File goahReject = new File(goahInput.getParent() + "/goa_human_reject.tsv")
        //geneOntology.readGeneAssociation(goahInput, goahOutput, goahReject, humanGeneId, "Homo sapiens")
        //geneOntology.loadGeneAssociation(biomart, goahOutput, props.get("pathway_data_table"))

        geneOntology.readGeneAssociation(goahInput, goahOutput, "Homo sapiens")
        geneOntology.loadGeneAssociation(databaseType, goahOutput, props, "Homo sapiens")

        // process Gene Association data for Mus musculus
        File goamInput = new File(props.get("gene_association_mouse"))
        File goamOutput = new File(goamInput.getParent() + "/goa_mgi.tsv")
        File goamReject = new File(goamInput.getParent() + "/goa_mgi_reject.tsv")
        //geneOntology.readGeneAssociation(goamInput, goamOutput, goamReject, mouseGeneId, "Mus musculus")
        //geneOntology.loadGeneAssociation(biomart, goamOutput, props.get("pathway_data_table"))

//        geneOntology.readGeneAssociation(goamInput, goamOutput)
//        geneOntology.loadGeneAssociation(deapp, goamOutput, props.get("pathway_data_table"), "Mus musculus")

        // process Gene Association data for Rattus norvegicus
        File goarInput = new File(props.get("gene_association_rat"))
        File goarOutput = new File(goarInput.getParent() + "/goa_rgd.tsv")
        File goarReject = new File(goarInput.getParent() + "/goa_rgd_reject.tsv")
        //geneOntology.readGeneAssociation(goarInput, goarOutput, goarReject, ratGeneId, "Rattus norvegicus")
        //geneOntology.loadGeneAssociation(biomart, goarOutput, props.get("pathway_data_table"))

//        geneOntology.readGeneAssociation(goarInput, goarOutput)
//        geneOntology.loadGeneAssociation(deapp, goarOutput, props.get("pathway_data_table"), "Rattus norvegicus")

        // create indexes
        geneOntology.createIndex(databaseType, deapp, props.get("pathway_data_table"))

        // populate DE_PATHWAY
        geneOntology.loadPathway(databaseType, props)

        Map pathwayId = geneOntology.getPathwayId(deapp, "GO")

        // populate DE_PATHWAY_GENE
        geneOntology.loadPathwayGene(databaseType, props)

        // populate BIO_MARKER
        geneOntology.loadBioMarker(databaseType, props)

        // populate BIO_DATA_CORREL_DESCR
        long bioDataCorrelDescrId = geneOntology.loadBioDataCorrelDescr(databaseType, props)

        // populate BIO_DATA_CORRELATION
        geneOntology.loadBioDataCorrelation(databaseType, props, bioDataCorrelDescrId)

        // populate SEARCH_KEYWORD
        geneOntology.loadSearchKeyword(databaseType, props)

        // populate SEARCH_KEYWORD_TERM
        geneOntology.loadSearchKeywordTerm(databaseType, props)
    }

    void loadPathway(String dabaseType, Properties props) {
        if (props.get("skip_de_pathway").toString().toLowerCase().equals("yes")) {
            log.info "Skip loading records into DE_PATHWAY ..."
        } else {
            log.info "Start loading DE_PATHWAY for GO:  " + new Date()

            Pathway p = new Pathway()
            p.setSource("GO")
            p.setDeapp(deapp)
            //p.loadPathway(goOutput)
            p.loadPathway(dabaseType, props.get("pathway_table"), props.get("pathway_data_table"))

            log.info "End loading DE_PATHWAY for GO:  " + new Date()
        }
    }

    void loadPathwayGene(String dabaseType, Properties props) {
        if (props.get("skip_de_pathway_gene").toString().toLowerCase().equals("yes")) {
            log.info "Skip loading new records into DE_PATHWAY_GENE ..."
        } else {
            PathwayGene pg = new PathwayGene()
            pg.setSource("GO")
            pg.setDeapp(deapp)

            // load de_pathawy_gene for human
            log.info "Start loading DE_PATHWAY_GENE for GO:  " + new Date()
            //pg.loadPathwayGene(goahOutput, humanGeneId, pathwayId)
            pg.loadPathwayGene(dabaseType, props.get("pathway_data_table"))

            // load de_pathawy_gene for Mus musculus
            //log.info "Start loading DE_PATHWAY_GENE for GO Mouse ..."
            //pg.loadPathwayGene(goamOutput, mouseGeneId, pathwayId)

            // load de_pathawy_gene for Rattus norvegicus
            //log.info "Start loading DE_PATHWAY_GENE for GO Rat ..."
            //pg.loadPathwayGene(goarOutput, ratGeneId, pathwayId)

            log.info "End loading DE_PATHWAY_GENE for GO:  " + new Date()
        }
    }

    long loadBioDataCorrelDescr(String databaseType, Properties props) {
        BioDataCorrelDescr bdcd = new BioDataCorrelDescr()
        bdcd.setBiomart(biomart)
        bdcd.insertBioDataCorrelDescr(databaseType, "PATHWAY GENE", "PATHWAY GENE", "PATHWAY")
        return bdcd.getBioDataCorrelId("PATHWAY GENE", "PATHWAY")
    }

    void loadBioDataCorrelation(String databaseType, Properties props, long bioDataCorrelDescrId) {
        log.info "Start loading BIO_DATA_CORRELATION:  " + new Date()

        if (props.get("skip_bio_data_correlation").toString().toLowerCase().equals("yes")) {
            log.info "Skip loading new records into BIO_DATA_CORRELATION ..."
        } else {
            BioDataCorrelation bdc = new BioDataCorrelation()
            bdc.setBiomart(deapp)
            bdc.setSource("GO")
            bdc.setBioDataCorrelDescrId(bioDataCorrelDescrId)

            String  pathwayDataTable = props.get("pathway_data_table")
            bdc.loadBioDataCorrelation(databaseType, pathwayDataTable)

            /*
             bdc.setOrganism("Homo sapiens")
             bdc.loadBioDataCorrelation(goahOutput, humanGeneId)
             bdc.setOrganism("Mus musculus")
             bdc.loadBioDataCorrelation(goamOutput, mouseGeneId)
             bdc.setOrganism("Rattus norvegicus")
             bdc.loadBioDataCorrelation(goarOutput, ratGeneId)
             */
        }

        log.info "End loading BIO_DATA_CORRELATION:  " + new Date()
    }

    void loadSearchKeyword(String databaseType, Properties props) {
        log.info "Start loading search_keyword:  " + new Date()

        if (props.get("skip_search_keyword").toString().toLowerCase().equals("yes")) {
            log.info "Skip loading new records into SEARCH_KEYWORD ..."
        } else {
            SearchKeyword sk = new SearchKeyword()
            sk.setSearchapp(searchapp)

            sk.loadPathwaySearchKeyword(databaseType, "GO")
            sk.loadGeneSearchKeyword(databaseType)
        }

        log.info "End loading search_keyword:  " + new Date()
    }


    void loadSearchKeywordTerm(String databaseType, Properties props) {
        log.info "Start loading search_keyword_term:  " + new Date()

        if (props.get("skip_search_keyword_term").toString().toLowerCase().equals("yes")) {
            log.info "Skip loading new records into SEARCH_KEYWORD_TERM  ..."
        } else {
            SearchKeywordTerm skt = new SearchKeywordTerm()
            skt.setSearchapp(searchapp)
            skt.loadSearchKeywordTerm(databaseType)
        }

        log.info "End loading search_keyword_term:  " + new Date()
    }


    void loadBioMarker(String databaseType, Properties props) {
        if (databaseType.equals("oracle")) {
            loadBioMarker(props)
        } else if (databaseType.equals("netezza")) {
            loadNetezzaBioMarker(props)
        } else {
            log.info("Database $databaseType is not supported.")
        }
    }


    void loadNetezzaBioMarker(Properties props) {

        String pathwayTable = props.get("pathway_table")
        String pathwayDataTable = props.get("pathway_data_table")

        if (props.get("skip_bio_marker").toString().toLowerCase().equals("yes")) {
            log.info "Skip loading new records into Netezza BIO_MARKER ..."
        } else {
            log.info "Start loading GO pathway into Netezza BIO_MARKER:  " + new Date()

            String qry = """ insert into biomart.bio_marker(BIO_MARKER_ID, bio_marker_name, bio_marker_description, organism,
								primary_source_code, primary_external_id, bio_marker_type)
                             select next value for SEQ_BIO_DATA_ID, t.name, t.descr, t.organism, t.source, t.pathway, t.type
                             from (
                                 select distinct t1.descr as name, t1.descr, t2.organism, 'GO' as source, t2.pathway, 'PATHWAY' as type
                                 from $pathwayTable t1, $pathwayDataTable t2
                                 where t1.pathway=t2.pathway and t2.pathway not in
                                     (select primary_external_id from biomart.bio_marker
                                      where bio_marker_type='PATHWAY' and primary_source_code='GO')
                             ) t
					    """
            log.info("BIO_MARKER: " + qry)
            deapp.execute(qry)

            log.info "End loading GO pathway into Netezza BIO_MARKER: " + new Date()
        }
    }


    void loadBioMarker(Properties props) {

        String pathwayTable = props.get("pathway_table")
        String pathwayDataTable = props.get("pathway_data_table")

        if (props.get("skip_bio_marker").toString().toLowerCase().equals("yes")) {
            log.info "Skip loading new records into BIO_MARKER ..."
        } else {
            log.info "Start loading GO pathway into BIO_MARKER:  " + new Date()

            String qry = """ insert into biomart.bio_marker(bio_marker_name, bio_marker_description, organism,
								primary_source_code, primary_external_id, bio_marker_type)
						 select distinct t1.descr, t1.descr, t2.organism, 'GO', t2.pathway, 'PATHWAY'
						 from $pathwayTable t1, $pathwayDataTable t2
						 where t1.pathway=t2.pathway and t2.pathway not in
						     (select primary_external_id from biomart.bio_marker
							  where bio_marker_type='PATHWAY' and primary_source_code='GO')
					"""
            deapp.execute(qry)

            log.info "End loading GO pathway into BIO_MARKER: " + new Date()
        }
    }


    void loadBioMarker(Sql deapp, String pathwayTable, String pathwayDataTable) {
        log.info "Start loading GO pathway into BIO_MARKER ..."

        String qry = """ insert into biomart.bio_marker(bio_marker_name, bio_marker_description, organism,
								primary_source_code, primary_external_id, bio_marker_type)
						 select distinct t1.descr, t1.descr, t2.organism, 'GO', t2.pathway, 'PATHWAY'
						 from gene_ontology t1, gene_ontology_data t2
						 where t1.pathway=t2.pathway and t2.pathway not in 
						     (select primary_external_id from biomart.bio_marker 
							  where bio_marker_type='PATHWAY' and primary_source_code='GO')
					"""
        deapp.execute(qry)

        log.info "End loading GO pathway into BIO_MARKER ..."
    }


    void readGeneOntology(File goInput, File goOutput) {

        if (goInput.size() > 0) {
            log.info("Start processing " + goInput.toString())
        } else {
            throw new RuntimeException(goInput.toString() + " is empty")
        }

        StringBuffer sb = new StringBuffer()

        boolean termFlag = false
        String goId = "", goName = ""
        goInput.eachLine {

            if (it.indexOf("[Term]") != -1) {
                termFlag = true

                // only keep data for human, mouse and rat
                if ((goId.size() > 0) && goName.size() > 0) sb.append("$goId\t$goName\n")
                goId = ""
                goName = ""
            }

            if (termFlag && (it.indexOf("id: ") != -1)) {
                goId = it.replace("id: ", "").trim()
            }

            if (termFlag && (it.indexOf("name: ") != -1)) {
                goName = it.replace("name: ", "").trim()
                termFlag = false
            }
        }

        if (goOutput.size() > 0) {
            goOutput.delete()
            goOutput.createNewFile()
        }
        goOutput.append(sb.toString())
    }


    void loadGeneOntology(String databaseType, File goOutput, Properties props) {

        String pathwayTable = props.get("pathway_table")

        if (databaseType.equals("oracle")) {
            loadOracleGeneOntology(goOutput, pathwayTable)
        } else if (databaseType.equals("netezza")) {
            loadNetezzaGeneOntology(goOutput, props)
        } else if (databaseType.equals("postgresql")) {
            loadPostgreSQLGeneOntology(goOutput, props)
        } else if (databaseType.equals("db2")) {
            loadDB2GeneOntology(goOutput, props)
        } else {
            log.info "Database support for $databaseType will be added soon ... "
        }
    }

    void loadDB2GeneOntology(File goOutput, Properties props) {

    }

    void loadPostgreSQLGeneOntology(File goOutput, Properties props) {

    }

    void loadNetezzaGeneOntology(File goOutput, Properties props) {

        String pathwayTable = props.get("pathway_table")
        String nzload = props.get("nzload")
        String user = props.get("biomart_username")
        String password = props.get("biomart_password")
        String host = props.get("url").split(":")[2].toString().replaceAll("/") { "" }

        def command = "$nzload -u $user -pw $password -host \"$host\" -db transmart -t $pathwayTable -delim \"\\t\" -outputDir \"c:/temp\" -df \"$goOutput\""
        log.info "nzload command: " + command
        def proc = command.execute()
        proc.waitFor()
    }

    void loadOracleGeneOntology(File goOutput, String pathwayTable) {

        log.info "Start loading $pathwayTable: " + new Date()

        if (goOutput.size() > 0) {
            log.info("Start loading " + goOutput.toString())
        } else {
            throw new RuntimeException(goOutput.toString() + " is empty")
        }

        String qry = " insert into ${pathwayTable}(pathway, descr) values(?, ?)"

        deapp.withTransaction {
            deapp.withBatch(qry, { stmt ->
                goOutput.eachLine {
                    String[] str = it.split("\t")
                    stmt.addBatch([str[0], str[1]])
                }
            }
            )
        }

        log.info "End loading $pathwayTable: " + new Date()
    }


    void readGeneAssociation(File goaInput, File goaOutput, File goaReject, Map geneList, String organism) {

        Map goa = [:]

        if (goaInput.size() > 0) {
            log.info("Start processing " + goaInput.toString())
        } else {
            throw new RuntimeException(goaInput.toString() + " is empty")
        }

        String[] str = []
        StringBuffer sb = new StringBuffer()

        goaInput.eachLine {
            if (it.indexOf("!") == -1) {
                str = it.split("\t")
                //sb.append(str[4].trim() + "\t" + str[2].trim() + "\n")
                goa[str[4].trim() + "\t" + str[2].trim()] = 1
            }
        }

        if (goaOutput.size() > 0) {
            goaOutput.delete()
            goaOutput.createNewFile()
        }

        StringBuffer sbReject = new StringBuffer()
        goa.each { k, v ->
            String[] s = k.split("\t")
            if (geneList[s[1]].equals(null)) {
                sbReject.append(k + "\n")
            } else {
                sb.append(s[0] + "\t" + geneList[s[1]] + "\t" + s[1] + "\t" + organism + "\n")
            }
        }
        goaOutput.append(sb.toString())
        goaReject.append(sbReject.toString())
    }

    void readGeneAssociation(File goaInput, File goaOutput) {
        readGeneAssociation(goaInput, goaOutput, "")
    }

    void readGeneAssociation(File goaInput, File goaOutput, String organism) {

        if (organism.equals("")) organism = "Homo sapiens"

        Map goa = [:]

        if (goaInput.size() > 0) {
            log.info("Start processing " + goaInput.toString() + ":  " + new Date())
        } else {
            throw new RuntimeException(goaInput.toString() + " is empty")
        }

        String[] str = []
        StringBuffer sb = new StringBuffer()

        goaInput.eachLine {
            if (it.indexOf("!") == -1) {
                str = it.split("\t")
                goa[str[4].trim() + "\t" + str[2].trim()] = 1
            }
        }

        if (goaOutput.size() > 0) {
            goaOutput.delete()
            goaOutput.createNewFile()
        }

        goa.each { k, v ->
            sb.append(organism.toUpperCase() + "\t" + k + "\n")
        }
        goaOutput.append(sb.toString())

        log.info("End processing " + goaInput.toString() + ":  " + new Date())
    }


    void loadGeneAssociation(Sql deapp, File goaOutput, String pathwayDataTable) {

        if (goaOutput.size() > 0) {
            log.info("Start loading " + goaOutput.toString() + ": " + new Date())
        } else {
            throw new RuntimeException(goaOutput.toString() + " is empty")
        }

        String qry = " insert into ${pathwayDataTable}(pathway, gene_id, gene_symbol, organism) values(?, ?, ?, ?)"

        deapp.withTransaction {
            deapp.withBatch(qry, { stmt ->
                goaOutput.eachLine {
                    String[] str = it.split("\t")
                    stmt.addBatch([
                            str[0],
                            str[1],
                            str[2],
                            str[3]
                    ])
                }
            }
            )
        }

        log.info "End loading ${goaOutput.toString()}: " + new Date()
    }


    void createIndex(String databaseType, Sql biomart, String pathwayDataTable) {
        if (databaseType.equals("oracle")) createIndex(biomart, pathwayDataTable)
    }

    void createIndex(Sql biomart, String pathwayDataTable) {

        log.info "Start creating indexes ..."

        String qry = "create index idx_god_symbol on ${pathwayDataTable} (upper(gene_symbol)) "
        biomart.execute(qry)

        qry = " create bitmap index idx_god_organism on ${pathwayDataTable} (upper(organism))"
        biomart.execute(qry)

        log.info "End creating indexes ..."
    }


    void loadGeneAssociation(String databaseType, File goaOutput, Properties props, String organism) {

        String pathwayDataTable = props.get("pathway_data_table")

        if (databaseType.equals("oracle")) {
            loadOracleGeneAssociation(goaOutput, pathwayDataTable, organism)
        } else if (databaseType.equals("netezza")) {
            loadNetezzaGeneAssociation(goaOutput, props)
        } else if (databaseType.equals("postgresql")) {
            loadPostgreSQLGeneAssociation(goaOutput, props)
        } else if (databaseType.equals("db2")) {
            loadDB2GeneAssociation(goaOutput, props)
        } else {
            log.info "Database support for $databaseType will be added soon ... "
        }
    }

    void loadDB2GeneAssociation(File goaOutput, Properties props) {

    }

    void loadPostgreSQLGeneAssociation(File goaOutput, Properties props) {

    }

    void loadNetezzaGeneAssociation(File goaOutput, Properties props) {

        String pathwayDataTable = props.get("pathway_data_table")
        String nzload = props.get("nzload")
        String user = props.get("biomart_username")
        String password = props.get("biomart_password")
        String host = props.get("url").split(":")[2].toString().replaceAll("/") { "" }

        def command = "$nzload -u $user -pw $password -host \"$host\" -db transmart -t $pathwayDataTable -delim \"\\t\" -outputDir \"c:/temp\" -df \"$goaOutput\""
        log.info "nzload command: " + command
        def proc = command.execute()
        proc.waitFor()
    }

    void loadOracleGeneAssociation(File goaOutput, String pathwayDataTable, String organism) {

        if (goaOutput.size() > 0) {
            log.info("Start loading " + goaOutput.toString() + ":  " + new Date())
        } else {
            throw new RuntimeException(goaOutput.toString() + " is empty")
        }

        String qry = " insert into ${pathwayDataTable}(pathway, gene_symbol, organism) values(?, ?, ?)"

        deapp.withTransaction {
            deapp.withBatch(qry, { stmt ->
                goaOutput.eachLine {
                    String[] str = it.split("\t")
                    stmt.addBatch([
                            str[0],
                            str[1],
                            organism
                    ])
                }
            }
            )
        }

        log.info("End loading " + goaOutput.toString() + ":  " + new Date())
    }

    Map getGeneId(Sql biomart, String taxId, String geneInfoTable) {

        Map geneId = [:]
        String qry = "select upper(gene_symbol) gene_symbol, gene_id from ${geneInfoTable} where tax_id=?"
        biomart.eachRow(qry, [taxId]) {
            geneId[it.gene_symbol] = it.gene_id
        }
        return geneId
    }


    Map getPathwayId(Sql deapp, String source) {

        Map pathwayId = [:]
        String qry = "select externalid, id from de_pathway where source=?"
        deapp.eachRow(qry, [source]) {
            pathwayId[it.externalid] = it.id
        }
        return pathwayId
    }


    void createPathwayTable(String databaseType, Properties props) {

        if (props.get("skip_create_pathway_table").toString().toLowerCase().equals("yes")) {
            log.info("Skip loading Gene Ontology ...")
        } else {
            String pathwayTable = props.get("pathway_table")
            String pathwayDataTable = props.get("pathway_data_table")

            if (databaseType.equals("oracle")) {
                createOraclePathwayTable(deapp, pathwayTable)
                createOraclePathwayDataTable(deapp, pathwayDataTable)
            } else if (databaseType.equals("netezza")) {
                createNetezzaPathwayTable(deapp, pathwayTable)
                createNetezzaPathwayDataTable(deapp, pathwayDataTable)
            } else if (databaseType.equals("postgresql")) {
                createPostgreSQLPathwayTable(deapp, pathwayTable)
                createPostgreSQLPathwayDataTable(deapp, pathwayDataTable)
            } else if (databaseType.equals("db2")) {
                createDB2PathwayTable(deapp, pathwayTable)
                createDB2PathwayDataTable(deapp, pathwayDataTable)
            } else {
                log.info "Database supporting for $databaseType will be added soon ... "
            }
        }
    }


    void createDB2PathwayTable(Sql deapp, String pathwayTable) {

    }

    void createPostgreSQLPathwayTable(Sql deapp, String pathwayTable) {
        createNetezzaPathwayTable(deapp, pathwayTable)
    }

    void createNetezzaPathwayTable(Sql deapp, String pathwayTable) {

        String currentSchema = Util.getNetezzaCurrentSchema(deapp)

        log.info "Start creating Netezza table: ${pathwayTable}"

        String qry = """ create table ${pathwayTable} (
							pathway  		varchar(100),
							descr			varchar(500)
						 )
					"""

        String qry1 = "select count(*) from information_schema.tables where upper(table_name)=? and TABLE_SCHEMA='$currentSchema'"
        log.info qry1 + ": [$pathwayTable]"

        if (deapp.firstRow(qry1, [pathwayTable.toUpperCase()])[0] > 0) {
            log.info "Drop Netezza table $pathwayTable ..."
            qry1 = "drop table ${pathwayTable}"
            deapp.execute(qry1)
        }

        deapp.execute(qry)

        log.info "End creating Netezza table: ${pathwayTable}"
    }


    void createOraclePathwayTable(Sql deapp, String pathwayTable) {

        log.info "Start creating Oracle table: ${pathwayTable}"

        String qry = """ create table ${pathwayTable} (
							pathway  		varchar2(100),
							descr			varchar2(500)
						 )
					"""

        String qry1 = "select count(*)  from user_tables where table_name=?"
        if (deapp.firstRow(qry1, [pathwayTable.toUpperCase()])[0] > 0) {
            qry1 = "drop table ${pathwayTable} purge"
            deapp.execute(qry1)
        }

        deapp.execute(qry)

        log.info "End creating Oracle table: ${pathwayTable}"
    }


    void createDB2PathwayDataTable(Sql deapp, String pathwayDataTable) {

    }


    void createPostgreSQLPathwayDataTable(Sql deapp, String pathwayDataTable) {
        createNetezzaPathwayDataTable(deapp, pathwayDataTable)
    }

    void createNetezzaPathwayDataTable(Sql deapp, String pathwayDataTable) {

        String currentSchema = Util.getNetezzaCurrentSchema(deapp)

        log.info "Start creating Netezza table: ${pathwayDataTable}"

        String qry = """ create table ${pathwayDataTable} (
							organism        varchar(100),
							pathway  		varchar(100),
							gene_symbol     varchar(200) --,
							-- gene_id			varchar(20)
						 )
					"""

        String qry1 = "select count(*) from information_schema.tables where upper(table_name)=? and TABLE_SCHEMA='$currentSchema'"
        log.info qry1

        if (deapp.firstRow(qry1, [pathwayDataTable.toUpperCase()])[0] > 0) {
            log.info "Drop Netezza table: ${pathwayDataTable}"
            qry1 = "drop table ${pathwayDataTable}"
            deapp.execute(qry1)
        }

        deapp.execute(qry)

        log.info "End creating Netezza table: ${pathwayDataTable}"

    }


    void createOraclePathwayDataTable(Sql deapp, String pathwayDataTable) {

        log.info "Start creating Oracle table: ${pathwayDataTable}"

        String qry = """ create table ${pathwayDataTable} (
							pathway  		varchar2(100),
							gene_id			varchar2(20),
							gene_symbol		varchar2(200),
							organism		varchar2(100)
						 )
					"""

        String qry1 = "select count(*)  from user_tables where table_name=?"
        if (deapp.firstRow(qry1, [
                pathwayDataTable.toUpperCase()
        ])[0] > 0) {
            qry1 = "drop table ${pathwayDataTable} purge"
            deapp.execute(qry1)
        }

        deapp.execute(qry)

        log.info "End creating Oracle table: ${pathwayDataTable}"
    }


    void setSearchapp(Sql searchapp) {
        this.searchapp = searchapp
    }

    void setBiomart(Sql biomart) {
        this.biomart = biomart
    }

    void setDeapp(Sql deapp) {
        this.deapp = deapp
    }
}
