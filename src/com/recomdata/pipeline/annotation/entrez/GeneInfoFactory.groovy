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

class GeneInfoFactory {

    private static final Logger log = Logger.getLogger(GeneInfoFactory)

    GeneInfo createGeneInfo() {

        // load the default property file: conf/transmart.properties
        Properties props = Util.loadConfiguration()
        String databaseType = props.get("common.databaseType")

        GeneInfo gi = selectGeneInfo(databaseType)

        if (props.get("entrez.skip").toString().toLowerCase().equals("yes")) {
            log.info "Skip loading Entrez data ..."
        } else {
            String geneInfoSource = props.get("entrez.gene_info_source")
            File geneInfo = new File(geneInfoSource)
            File entrezGene = Util.createFile(geneInfoSource + ".tsv")
            File entrezSynonym = Util.createFile(geneInfoSource + ".synonym")

            Sql biomart = Util.createSqlFromPropertyFile(props, databaseType, "biomart")
            Sql searchapp = Util.createSqlFromPropertyFile(props, databaseType, "searchapp")

            gi.setDatabaseType(databaseType)
            gi.setProperties(props)
            gi.setBiomart(biomart)
            gi.setBiomartSchemaName(props.get("common.biomart.schema"))
            gi.setSearchapp(searchapp)
            gi.setSearchappSchemaName(props.get("common.searchapp.schema"))
            gi.setGeneInfoTable(props.get("entrez.gene_info_table").toString().toLowerCase())
            gi.setGeneSynonymTable(props.get("entrez.gene_synonym_table").toString().toLowerCase())

            gi.setGeneInfo(geneInfo)
            gi.setEntrezGene(entrezGene)
            gi.setEntrezSynonym(entrezSynonym)
            gi.setCurrentSchema(gi.getCurrentSchema(biomart))

            Map selectedOrganism = gi.getSelectedOrganism(props.get("entrez.selected_organism"))
            gi.setSelectedOrganism(selectedOrganism)
        }
        return gi
    }


    private GeneInfo selectGeneInfo(String databaseType) {
        if (databaseType.equals("oracle")) {
            return new OracleGeneInfo()
        } else if (databaseType.equals("netezza")) {
            return new NetezzaGeneInfo()
        } else if (databaseType.equals("postgresql")) {
            return new PostgreSQLGeneInfo()
        } else if (databaseType.equals("db2")) {
            //return new DB2GeneInfo()
        } else {
            log.info "Database support for $databaseType will be added soon ... "
            return null
        }
    }
}
