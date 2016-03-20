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

import groovy.sql.Sql
import org.apache.log4j.Logger

abstract class GeneInfo {

    private static final Logger log = Logger.getLogger(GeneInfo)

    Properties props
    Map selectedOrganismMap

    // file names for input (geneInfo) and output (entrez and synonym)
    File geneInfo, entrezGene, entrezSynonym

    Sql biomart, searchapp
    String geneInfoTable, geneSynonymTable, databaseType
    String currentSchema, biomartSchemaName, searchappSchemaName

    abstract String getCurrentSchema(Sql sql)
    abstract void loadGeneInfo()
    abstract void loadGeneSynonym()
    abstract void dropGeneInfoTable()
    abstract void createGeneInfoTable()
    abstract void createGeneSynonymTable()
    abstract void dropGeneSynonymTable()
    abstract void loadSearchKeywordTerm()
    abstract void loadSearchKeyword()

    /**
     * set a map for tax_id:organism and use it to filter gene info data
     *
     * @param selectedOrganismMap
     */
    void setSelectedOrganism(Map selectedOrganismMap) {
        this.selectedOrganismMap = selectedOrganismMap
    }

    /**
     * extract a map for tax_id:organism from the property file conf/transmart.properties
     *
     * @param selectedOrganisms
     * @return
     */
    Map getSelectedOrganism(String selectedOrganisms) {

        Map selectedOrganismMap = [:]

        if (selectedOrganisms.indexOf(";")) {
            String[] oragnisms = selectedOrganisms.split(";")
            for (int n in 0..oragnisms.size() - 1) {
                String[] temp = oragnisms[n].split(":")
                selectedOrganismMap[temp[0]] = temp[1]
            }
        } else {
            selectedOrganismMap[selectedOrganisms.split(":")[0]] = selectedOrganisms.split(":")[1]
        }

        return selectedOrganismMap
    }

    void loadOrganismGeneInfo() {
        selectedOrganismMap.each { taxonomyId, organism ->
            log.info "Start processing & loading Entrez gene and synonym data ... "

            extractSelectedGeneInfo(taxonomyId, organism)

            createGeneInfoTable(props.get("entrez.skip_create_gene_info_table").toString().toLowerCase())
            createGeneSynonymTable(props.get("entrez.skip_create_gene_synonym_table").toString().toLowerCase())

            loadGeneInfo(props.get("entrez.skip_load_gene_info").toString().toLowerCase())
            loadGeneSynonym(props.get("entrez.skip_load_gene_synonym").toString().toLowerCase())

            loadBioMarker(props.get("entrez.skip_load_bio_marker").toString().toLowerCase(), taxonomyId, organism)
            loadBioDataUid(props.get("entrez.skip_load_bio_data_uid").toString().toLowerCase(), taxonomyId, organism)
            loadBioDataExtCode(props.get("entrez.skip_load_bio_data_ext_code").toString().toLowerCase(), taxonomyId, organism)

            loadSearchKeyword(props.get("entrez.skip_load_search_keyword").toString().toLowerCase())
            loadSearchKeywordTerm(props.get("entrez.skip_load_search_keyword_term").toString().toLowerCase())

            dropGeneInfoTable("yes")
            dropGeneSynonymTable("yes")

            log.info "End processing & loading Entrez gene and synonym data ... \n"
        }
    }

    abstract void loadBioMarker(String taxonomyId, String organism)
    abstract void loadBioDataUid(String taxonomyId, String organism)
    abstract void loadBioDataExtCode(String taxonomyId, String organism)

    /**
     * extract tax_id(0), GeneID(1), Symbol(2), and Description(8) for a gene
     * @param str
     * @param taxonomyId
     * @return
     */
    String getGeneInfo(String[] str) {
        return str[0] + "\t" + str[1] + "\t" + str[2] + "\t" + str[8] + "\n"
    }

    /**
     *  extract tax_id(0), GeneID(1), Symbol(2), and Synonyms (4) for a gene's synonym(s)
     *
     * @param str
     * @param taxonomyId
     * @return
     */
    StringBuffer getGeneSynonym(String[] str) {
        StringBuffer sb = new StringBuffer()

        if (str[4].indexOf("|") != -1) {
            String[] tmp = str[4].split(/\|/)
            tmp.each {
                if (!it.equals(null) && (it.trim().size() > 0))
                    sb.append(str[0] + "\t" + str[1] + "\t" + str[2] + "\t" + it + "\n")
            }
        } else {
            sb.append(str[0] + "\t" + str[1] + "\t" + str[2] + "\t" + str[4] + "\n")
        }

        return sb
    }

    /**
     *
     * 0	tax_id*		the unique identifier provided by NCBI Taxonomy for the species or strain/isolate
     * 1	GeneID*		the unique identifier for a gene ASN1:  geneid
     * 2	Symbol*		the default symbol for the gene ASN1:  gene->locus
     * 3	LocusTag
     * 4	Synonyms*
     * 5	dbXrefs
     * 6	chromosome
     * 7	map_location
     * 8	description
     * 9	type_of_gene
     * 10	Symbol_from_nomenclature_authority
     * 11	Full_name_from_nomenclature_authority
     * 12	Nomenclature_status
     * 13	Other_designations
     * 14	Modification_date
     *
     * @param geneInfo
     */
    void extractSelectedGeneInfo(String taxonomyId, String organism) {

        StringBuffer sbGene = new StringBuffer()
        StringBuffer sbSynonym = new StringBuffer()

        if (geneInfo.size() > 0) {
            log.info "Start extracting data for $taxonomyId:$organism from Gene Info file: " + geneInfo.toString()
            geneInfo.eachLine {
                String[] str = it.split(/\t/)
                if (it.indexOf("#Format") != -1) {
                    //String[] s = it.replace("#Format: ", "").split(" ")
                    //for(int i in 0 .. s.size()-1) println i + "\t" + s[i]
                } else {
                    if (!str[0].equals(null) && (str[0] == taxonomyId)) {
                        sbGene.append(getGeneInfo(str))

                        if (!str[4].equals(null) && !str[4].equals("-")) {
                            sbSynonym.append(getGeneSynonym(str))
                        }
                    }
                }
            }
            log.info "End extracting data for $taxonomyId:$organism from Gene Info file: " + geneInfo.toString() + "\n"
        } else {
            log.error(geneInfo.toString() + " is empty.")
        }

        if (sbGene.size() > 0) entrezGene.append(sbGene.toString())
        if (sbSynonym.size() > 0) entrezSynonym.append(sbSynonym.toString())
    }

    /**
     * check if Entrez genes need load into  $currentSchema.$geneInfoTable
     *
     * @param isSkip "yes" - skip; otherwise - load
     */
    void loadGeneInfo(String isSkip) {
        if (isSkip.equals("yes")) {
            log.info("Skip loading Entrez genes (${entrezGene.toString()}) into $currentSchema.$geneInfoTable ($databaseType) ...")
        } else {
            log.info("Start loading Entrez genes (${entrezGene.toString()}) into $currentSchema.$geneInfoTable ($databaseType) ...")
            loadGeneInfo()
            log.info("End loading Entrez genes (${entrezGene.toString()}) into $currentSchema.$geneInfoTable ($databaseType) ... \n")
        }
    }

    /**
     *  check if Entrez genes and synonyms need load into $currentSchema.$geneSynonymTable
     *
     * @param isSkip
     */
    void loadGeneSynonym(String isSkip) {
        if (isSkip.equals("yes")) {
            log.info("Skip loading Entrez genes and synonyms (${entrezSynonym.toString()}) into $currentSchema.$geneSynonymTable ($databaseType) ...")
        } else {
            log.info("Start loading Entrez genes and synonyms (${entrezSynonym.toString()}) into $currentSchema.$geneSynonymTable ($databaseType) ...")
            loadGeneSynonym()
            log.info("End loading Entrez genes and synonyms (${entrezSynonym.toString()}) into $currentSchema.$geneSynonymTable ($databaseType) ... \n")
        }
    }

    /**
     *  check if Entrez genes need load into BIOMART.BIO_MARKER
     *
     * @param isSkip
     * @param taxonomyId
     * @param organism
     */
    void loadBioMarker(String isSkip, String taxonomyId, String organism) {
        if (isSkip.equals("yes")) {
            log.info("Skip loading Entrez genes ($taxonomyId:$organism) into ${biomartSchemaName}.BIO_MARKER ($databaseType) ...")
        } else {
            log.info("Start loading Entrez genes ($taxonomyId:$organism) into ${biomartSchemaName}.BIO_MARKER ($databaseType) ...")
            loadBioMarker(taxonomyId, organism)
            log.info("Start loading Entrez genes ($taxonomyId:$organism) into ${biomartSchemaName}.BIO_MARKER ($databaseType) ... \n")
        }
    }

    /**
     *  check if Entrez genes need load into BIOMART.BIO_DATA_UID
     *
     * @param isSkip
     * @param taxonomyId
     * @param organism
     */
    void loadBioDataUid(String isSkip, String taxonomyId, String organism) {
        if (isSkip.equals("yes")) {
            log.info("Skip loading Entrez genes ($taxonomyId:$organism) into ${searchappSchemaName}.BIO_DATA_UID ($databaseType) ...")
        } else {
            log.info("Start loading Entrez genes ($taxonomyId:$organism) into ${searchappSchemaName}.BIO_DATA_UID ($databaseType) ...")
            loadBioDataUid(taxonomyId, organism)
            log.info("Start loading Entrez genes ($taxonomyId:$organism) into ${searchappSchemaName}.BIO_DATA_UID ($databaseType) ... \n")
        }
    }

    /**
     *  check if Entrez genes need load into BIOMART.BIO_DATA_EXT_CODE
     *
     * @param isSkip
     * @param taxonomyId
     * @param organism
     */
    void loadBioDataExtCode(String isSkip, String taxonomyId, String organism) {
        if (isSkip.equals("yes")) {
            log.info("Skip loading Entrez genes and synonyms ($taxonomyId:$organism) into and ${searchappSchemaName}.BIO_DATA_EXT_CODE ($databaseType) ...")
        } else {
            log.info("Start loading Entrez genes and synonyms ($taxonomyId:$organism) into ${searchappSchemaName}.BIO_DATA_EXT_CODE ($databaseType) ...")
            loadBioDataExtCode(taxonomyId, organism)
            log.info("Start loading Entrez genes and synonyms ($taxonomyId:$organism) into ${searchappSchemaName}.BIO_DATA_EXT_CODE ($databaseType) ... \n")
        }
    }

    /**
     *  check if Entrez genes need load into SEARCHAPP.SEARCH_KEYWORD
     *
     * @param isSkip
     */
    void loadSearchKeyword(String isSkip) {
        if (isSkip.equals("yes")) {
            log.info("Skip loading Entrez genes into ${searchappSchemaName}.SEARCH_KEYWORD ($databaseType) ...")
        } else {
            log.info("Start loading Entrez genes into ${searchappSchemaName}.SEARCH_KEYWORD ($databaseType) ...")
            loadSearchKeyword()
            log.info("Start loading Entrez genes into ${searchappSchemaName}.SEARCH_KEYWORD ($databaseType) ... \n")
        }
    }

    /**
     *  check if Entrez genes and synonyms need load into SEARCHAPP.SEARCH_KEYWORD_TERM
     *
     * @param isSkip
     */
    void loadSearchKeywordTerm(String isSkip) {
        if (isSkip.equals("yes")) {
            log.info("Skip loading Entrez genes and synonyms into ${searchappSchemaName}.SEARCH_KEYWORD_TERM ($databaseType) ...")
        } else {
            log.info("Start loading Entrez genes and synonyms into ${searchappSchemaName}.SEARCH_KEYWORD_TERM ($databaseType) ...")
            loadSearchKeywordTerm()
            log.info("Start loading Entrez genes and synonyms into ${searchappSchemaName}.SEARCH_KEYWORD_TERM ($databaseType) ... \n")
        }
    }

    /**
     * check if need create the table $currentSchema.$geneInfoTable
     * @param isSkip
     */
    void createGeneInfoTable(String isSkip) {
        if (isSkip.equals("yes")) {
            log.info("Skip creating $currentSchema.$geneInfoTable ($databaseType) ...")
        } else {
            dropGeneInfoTable(isSkip)

            log.info("Start creating $currentSchema.$geneInfoTable ($databaseType) ...")
            createGeneInfoTable()
            log.info("End creating $currentSchema.$geneInfoTable ($databaseType) ... \n")
        }
    }

    /**
     * check if need drop the table $currentSchema.$geneInfoTable
     * @param isSkip
     */
    void dropGeneInfoTable(String isSkip) {
        log.info("Start dropping $currentSchema.$geneInfoTable ($databaseType) if exists ...")
        dropGeneInfoTable()
        log.info("End dropping $currentSchema.$geneInfoTable ($databaseType) ... \n")
    }

    /**
     * check if need create the table $currentSchema.$geneInfoTable
     * @param isSkip
     */
    void createGeneSynonymTable(String isSkip) {
        if (isSkip.equals("yes")) {
            log.info("Skip creating $currentSchema.$geneSynonymTable ($databaseType) ...")
        } else {
            dropGeneSynonymTable(isSkip)

            log.info("Start creating $currentSchema.$geneSynonymTable ($databaseType) ...")
            createGeneSynonymTable()
            log.info("End creating $currentSchema.$geneSynonymTable ($databaseType) ... \n")
        }
    }

    /**
     * check if need drop the table $currentSchema.$geneInfoTable
     * @param isSkip
     */
    void dropGeneSynonymTable(String isSkip) {
        log.info("Start dropping $currentSchema.$geneSynonymTable ($databaseType) if exists ...")
        dropGeneSynonymTable()
        log.info("End dropping $currentSchema.$geneSynonymTable ($databaseType) ... \n")
    }

    void setGeneInfoTable(String geneInfoTable) {
        this.geneInfoTable = geneInfoTable
    }

    void setGeneSynonymTable(String geneSynonymTable) {
        this.geneSynonymTable = geneSynonymTable
    }

    void setSearchapp(Sql searchapp) {
        this.searchapp = searchapp
    }

    void setBiomart(Sql biomart) {
        this.biomart = biomart
    }

    void setProperties(Properties props) {
        this.props = props
    }

    void setGeneInfo(File geneInfo) {
        this.geneInfo = geneInfo
    }

    void setEntrezSynonym(File entrezSynonym) {
        this.entrezSynonym = entrezSynonym
    }

    void setEntrezGene(File entrezGene) {
        this.entrezGene = entrezGene
    }

    void setCurrentSchema(String currentSchema) {
        this.currentSchema = currentSchema
    }

    void setDatabaseType(String databaseType) {
        this.databaseType = databaseType
    }

    void setBiomartSchemaName(String biomartSchemaName){
        this.biomartSchemaName = biomartSchemaName
    }

    void setSearchappSchemaName(String searchappSchemaName) {
        this.searchappSchemaName = searchappSchemaName
    }
}
