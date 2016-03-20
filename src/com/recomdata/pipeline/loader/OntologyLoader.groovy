package com.recomdata.pipeline.loader

import com.recomdata.pipeline.util.Util
import groovy.sql.Sql

import org.apache.log4j.Logger
import org.apache.log4j.PropertyConfigurator


class OntologyLoader {

    private static final Logger log = Logger.getLogger(OntologyLoader)
    String databaseType
    int batchSize, numberOfColumn

    static main(args) {

        PropertyConfigurator.configure("conf/log4j.properties");

        log.info("Start loading property file Ontology.properties ...")
        Properties props = Util.loadConfiguration("conf/Ontology.properties");

        Sql i2b2metadata = Util.createSqlFromPropertyFile(props, "i2b2metadata")

        OntologyLoader ol = new OntologyLoader()
        ol.setDatabaseType(Util.getDatabaseType(props))
        ol.setBatchSize(Integer.parseInt(props.get("batch_size")))
        ol.setNumberOfColumn(Integer.parseInt(props.get("number_of_column")))
        ol.loadOntologyFiles(props, i2b2metadata)
    }

    void loadOntologyFiles(Properties props, Sql i2b2metadata) {
        String fileLocation = props.get("file_location")
        String ontologyFile = props.get("ontology_file")
        String ontFile

        if (ontologyFile.indexOf(";") == -1) {
            ontFile = fileLocation + "/" + ontologyFile
            log.info("Start loading $ontFile ...")
            loadOntologyFile(ontFile, i2b2metadata)
            log.info("End loading $ontFile ...")
        } else {
            String[] ontologyFiles = ontologyFile.split(";")
            ontologyFiles.each {
                ontFile = fileLocation + "/" + it
                log.info("Start loading $ontFile ...")
                loadOntologyFile(ontFile, i2b2metadata)
                log.info("End loading $ontFile ...")
            }
        }
    }


    void loadOntologyFile(String ontFile, Sql i2b2metadata) {
        File ontology = new File(ontFile)

        if (ontology.size() > 0) {

            String ontologyTableName = getOntologyTableName(ontology)
            createOntologyTable(databaseType, ontologyTableName, i2b2metadata)
            StringBuffer sbQuery = createQuery(ontologyTableName, ontology)
//            log.info(sbQuery.toString())

            String[] str

            log.info("Start reading the ontology file: $ontFile ...")
            i2b2metadata.withTransaction {
                i2b2metadata.withBatch(batchSize, sbQuery.toString(), { stmt ->
                    int lineNum = 0
                    ontology.eachLine {
                        lineNum++
                        if (lineNum > 1) {
                            str = it.split("~")
//                            log.info("Size: \t ${str.size()}")

                            if (str.size() < numberOfColumn) {
                                str = fillBlankColumn(str)
//                                log.info(it)
                            }
                            // skip  5 - C_TOTALNUM; 7 - C_METADATAXML; 14 - C_COMMENT;
                            //      17 - UPDATE_DATE; 18 - DOWNLOAD_DATE; 19 - IMPORT_DATE
                            stmt.addBatch([str[0], str[1], str[2], str[3], str[4], str[5], str[6], str[7], str[8], str[9],
                                    str[10], str[11], str[12], str[13], str[14], str[15], str[16],
                                    str[20], str[21], str[22], str[23], str[24]]
                            )
                        }
                    }
                })
            }
        } else {
            log.info " $ontFile is empty or doesn't exist ... "
        }
    }

    String [] fillBlankColumn(String[] str) {
//        log.info("c_fullname: \t" + str[1])
        String [] columnValue = new String[numberOfColumn]
        for (int i = 0; i < numberOfColumn; i++) {
            columnValue[i] = ""
            if(i < str.size() && (!str[i].equals(null))) columnValue[i] = str[i]
        }
        return columnValue
    }

    StringBuffer createQuery(String ontologyTableName, File ontFile) {

        def line
        ontFile.withReader { line = it.readLine() }

        StringBuffer sb1 = new StringBuffer()
        StringBuffer sb2 = new StringBuffer()

        sb1.append("insert into $ontologyTableName ( \n")
        sb2.append("VALUES(")

        def str = line.split("~")
        int size = str.size()
        int num = 0
        str.each {
            num++
            if (num < str.size()) {
                sb1.append "\t" + it + ",\n"
                if (it.toString().indexOf("_DATE") == -1) {
                    sb2.append "?, "
                } else {
                    sb2.append("sysdate, ")
                }
            } else {
                sb1.append("\t" + it + ") \n")
                if (it.toString().indexOf("_DATE") == -1) {
                    sb2.append("?) \n")
                } else {
                    sb2.append("sysdate) \n")
                }
            }
        }

        return sb1.append(sb2.toString())
    }

    String getOntologyTableName(File ontFile) {
        String fileName = ontFile.getName()
        if (fileName.indexOf(".") != -1) {
            def str = fileName.split(/\./)
            return str[0]
        } else {
            return fileName
        }
    }

    void createOntologyTable(String databaseType, String tableName, Sql i2b2metadata) {

        if (databaseType.equals("oracle")) {
            createOracleOntologyTable(tableName, i2b2metadata)
        } else if (databaseType.equals("netezza")) {
            createNetezzaOntologyTable(tableName, i2b2metadata)
        } else if (databaseType.equals("postgresql")) {
            createPostgreSQLOntologyTable(tableName, i2b2metadata)
        } else if (databaseType.equals("db2")) {
            createDB2OntologyTable(tableName, i2b2metadata)
        } else {
            log.info "Database supporting for $databaseType will be added soon ... "
        }
    }

    void createNetezzaOntologyTable(String ontologyTableName, Sql i2b2metadata) {

    }

    void createPostgreSQLOntologyTable(String ontologyTableName, Sql i2b2metadata) {

    }

    void createDB2OntologyTable(String ontologyTableName, Sql i2b2metadata) {

    }

    void createOracleOntologyTable(String ontologyTableName, Sql i2b2metadata) {

        log.info "Start creating Oracle table: ${ontologyTableName}"

        String qry = """ create table ${ontologyTableName} as select * from i2b2 where 1=2"""

        String qry1 = "select count(*)  from user_tables where table_name=?"
        if (i2b2metadata.firstRow(qry1, [
                ontologyTableName.toUpperCase()
        ])[0] > 0) {
            qry1 = "drop table ${ontologyTableName} purge"
            i2b2metadata.execute(qry1)
        }

        i2b2metadata.execute(qry)

        log.info "End creating Oracle table: ${ontologyTableName}"
    }

    void setDatabaseType(String databaseType) {
        this.databaseType = databaseType
    }

    void setBatchSize(int batchSize) {
        this.batchSize = batchSize
    }

    void setNumberOfColumn(int numberOfColumn) {
        this.numberOfColumn = numberOfColumn
    }
}