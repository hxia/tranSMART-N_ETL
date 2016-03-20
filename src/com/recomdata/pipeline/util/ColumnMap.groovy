package com.recomdata.pipeline.util

import org.apache.log4j.Logger
import org.apache.log4j.PropertyConfigurator

import org.apache.poi.ss.usermodel.Cell
import org.apache.poi.ss.usermodel.Header
import org.apache.poi.ss.usermodel.Row
import org.apache.poi.xssf.usermodel.XSSFSheet
import org.apache.poi.xssf.usermodel.XSSFWorkbook

class ColumnMap {

    private static final Logger log = Logger.getLogger(ColumnMap)
    private Map ontology

    static main(args) {

        PropertyConfigurator.configure("conf/log4j.properties")

        ColumnMap ont = new ColumnMap()

        // read in Hip Replacement Ontology
        //ont.readOntology(("C:/Customers/TDI/hip.xlsx"))
        ont.readSpreadsheet(("C:/Customers/NIAID/template/Filaria Database - NO DATA.xlsx"))

        // generate insertion scripts for Hip Replacement Ontology
//        ont.createOntologyInsert("C:/Customers/TDI/create_DM_Ontology.sql")
    }


    void readSpreadsheet(String ont) {


        String visualAttr, basecode, node
        String hlevel, name
        ontology = [:]

        try {
            XSSFWorkbook wb = new XSSFWorkbook(ont)

//            XSSFSheet sheet1 = wb.getSheetAt(0);
//            for (Row row : sheet1) {
//                for (Cell cell : row) {
//                    CellReference cellRef = new CellReference(row.getRowNum(), cell.getColumnIndex());
//                    System.out.print(cellRef.formatAsString());
//                    System.out.print(" - ");
//
//                    switch (cell.getCellType()) {
//                        case Cell.CELL_TYPE_STRING:
//                            System.out.println(cell.getRichStringCellValue().getString());
//                            break;
//                        case Cell.CELL_TYPE_NUMERIC:
//                            if (DateUtil.isCellDateFormatted(cell)) {
//                                System.out.println(cell.getDateCellValue());
//                            } else {
//                                System.out.println(cell.getNumericCellValue());
//                            }
//                            break;
//                        case Cell.CELL_TYPE_BOOLEAN:
//                            System.out.println(cell.getBooleanCellValue());
//                            break;
//                        case Cell.CELL_TYPE_FORMULA:
//                            System.out.println(cell.getCellFormula());
//                            break;
//                        default:
//                            System.out.println();
//                    }
//                }
//            }

            if (wb.getNumberOfSheets() > 1) {
                for (int n = 0; n < wb.getNumberOfSheets(); n++) {
                    String sheetName = wb.getSheetName(n)
                    log.info("Sheet $n:\t" + sheetName)
                    XSSFSheet sheet = wb.getSheetAt(n)

                    Iterator rowIterator =  sheet.rowIterator()
                    int numOfColumn = 0
//                    while (rowIterator.hasNext())    // print all rows
                    if (rowIterator.hasNext())         // print header only
                    {
                        Row row = (Row) rowIterator.next();
                        //get the number of cells in the header row
                        numOfColumn = row.getPhysicalNumberOfCells();
                        for(int j=0; j<numOfColumn; j++){
                            Cell cell = row.getCell(j)
//                            log.info "   Cell type: " +  cell.getCellType()
                            if(cell.getCellType()==0) log.info "   Cell $j: " + cell.getNumericCellValue()
                            if(cell.getCellType()==1) log.info "   Cell $j: " + cell.getStringCellValue()
                            if(cell.getCellType()==3) log.info "   Cell $j: " + cell.getBooleanCellValue()
                            if(cell.getCellType()==3) log.info "   Cell $j: " + "BLANK"

                        }

//                        Iterator <Cell> cellIterator = row.cellIterator()
//                        while(cellIterator.hasNext()){
//                            Cell cell = cellIterator.next()
//                            if(cell.getCellType()==0) log.info cell.getNumericCellValue()
//                            if(cell.getCellType()==1) log.info cell.getStringCellValue()
//                            if(cell.getCellType()==3) log.info cell.getBooleanCellValue()
//                            if(cell.getCellType()==3) log.info "BLANK"
//                        }
                    }
//                    String columnName = sheet.getSheetName()
//                    log.info(n + ":\t" + columnName)
//                    if(sheet.getRow())
                }
            } else {
                // sometime using different sheet instead of the first one
                XSSFSheet sheet = wb.getSheetAt(0)
                Header header = sheet.getHeader()

                // get row counts
                int rowsCount = sheet.getLastRowNum()

                // read columns one by one
                for (int i = 0; i <= rowsCount; i++) {

                    visualAttr = ""
                    basecode = ""
                    node = ""
                    hlevel = ""
                    name = ""

                    Row row = sheet.getRow(i)

                    if (!row.getCell(0).equals(null)) {

                        visualAttr = getCellStringValue(row.getCell(0)).trim()
                        hlevel = getCellStringValue(row.getCell(1)).replace(".0", "")
                        if (!row.getCell(2).equals(null)) basecode = getCellStringValue(row.getCell(2)).trim()
                        node = getCellStringValue(row.getCell(3)).trim()
                        name = getCellStringValue(row.getCell(4)).trim()

                        ontology[node] = "$visualAttr|$hlevel|$basecode|$name"
                        log.info "[Row: $i: $visualAttr \t $hlevel \t $basecode \t $name \t $node]"
                    }
                }
            }
        }
        catch (Exception ex) {
            println ex.toString()
        } finally {}

    }


    void readOntologyWorkbook(String ontFile) {

        ontology = [:]

        StringBuffer sb = new StringBuffer()
        StringBuffer ont = new StringBuffer()
        ArrayList<String> str = new ArrayList<String>()
        String preLine, currentLine, xnode = "", xvalue = "", xstr = "", xont = "", codebase = ""
        int preLevel = 0
        int codeIndex = 0

        // store Ontology insert statements
        StringBuffer stmt = new StringBuffer()

        try {
            XSSFWorkbook wb = new XSSFWorkbook(ontFile)

            // sometime using different sheet instead of the first one (0)
            XSSFSheet sheet = wb.getSheetAt(0)
            Header header = sheet.getHeader()

            // get row counts
            int rowsCount = sheet.getLastRowNum()

            // read columns one by one
            for (int i = 0; i <= rowsCount; i++) {

                int index = 0
                boolean ended = false
                codebase = ""

                Row row = sheet.getRow(i)
                int columnsCount = row.getLastCellNum()
                for (int j in 0..columnsCount) {

                    if (!row.getCell(j).equals(null) && !ended) {

                        String s = getCellStringValue(row.getCell(j))
                        if (s.trim().size() > 0) {
                            str[j] = s.trim()
                            ended = true
                            index = j
                        }

                        log.info "[Row: $i Column: $j] \t" + str.toString() + ": $s"
                    }
                }

                // generate c_basecode
                /*		codeIndex++
                 if(str[0].indexOf("THR Event") != -1)
                 codebase = "TE" + codeIndex.toString().padLeft(3,"0")
                 else if(str[0].indexOf("Post-Discharge Facility Event") != -1)
                 codebase = "PD" + codeIndex.toString().padLeft(3,"0")
                 else codebase =  codeIndex.toString()
                 */

                // for Hip: 6;  DM: 11
                if (!row.getCell(11).equals(null)) {
                    codebase = getCellStringValue(row.getCell(11)).trim().replace(".0", "")
                }

                // extract and build ontology nodes
                boolean hadNull = false
                int level = -1
                String node = ""
                String initial = ""
                //node = "\\TDI\\"
                node = "\\"
                //sb.append(",TDI")
                for (int k in 0..index) {
                    //println "Index: $index \t" + str.toString()
                    if (!str[k].equals(null)) {
                        if (hadNull) println "Code: \t" + str[k]
                        else {
                            level++
                            node += str[k].trim() + "\\"
                            sb.append(",\"" + str[k].trim() + "\"")

                            if (k < index) initial += getInitial(str[k]).toUpperCase()
                        }
                    } else {
                        hadNull = true
                    }
                }

                if (!codebase.equals(null) && !codebase.equals("")) codebase = initial + ":" + codebase
                else codebase = ""

                log.info "[$codebase]: " + node
                // compute c_visualattributes: "LA" vs "FA"
                if (preLine.equals(null)) {
                    preLevel = level
                    preLine = node
                    currentLine = preLine
                    //ontology[node] = "FA:$level:$codebase:${str[index].trim()}"
                    ont.append("FA,$level,$codebase,\"$node\"" + sb.toString() + "\n")
                } else {
                    currentLine = node
                    /* if the c_hlevel is the same as the next one, then it's a "LA" node,
                     otherwise it's a "FA" node  */
                    if (preLevel < level) {
                        if (xnode.size() > 0) {
                            ont.append("FA,$xont\n")
                            //ontology[xnode] = "FA:" + xvalue //"$level:FA:$codebase:${str[index].trim()}"
                            xnode = ""
                            xvalue = ""
                            xstr = ""
                            xont = ""
                        }
                        xnode = node
                        xvalue = level + ":$codebase:${str[index].trim()}"
                        xstr = sb.toString()
                        xont = level + "," + codebase + ",\"" + node + "\"" + sb.toString()
                        preLine = currentLine
                        preLevel = level
                    } else if (preLevel == level) {
                        //log.info "PRE:" + preLine
                        //log.info "CUR:" + currentLine + "\n"

                        if (xnode.size() > 0) {
                            ont.append("LA,$xont\n")
                            ontology[xnode] = "LA:" + xvalue
                            xnode = ""
                            xvalue = ""
                            xstr = ""
                            xont = ""
                        }
                        ontology[node] = "LA:$level:$codebase:${str[index].trim()}"
                        ont.append("LA,$level,$codebase,\"$node\"" + sb.toString() + "\n")
                    } else {
                        preLevel = level
                        preLine = node
                        currentLine = preLine
                        ontology[node] = "FA:$level:$codebase:${str[index].trim()}"
                        ont.append("FA,$level,$codebase,\"$node\"" + sb.toString() + "\n")
                    }
                }

                sb.setLength(0)
            }
        } catch (Exception ex) {
            println ex.toString()
        } finally {}


        File f = new File("C:/Customers/TDI/DM.csv")
        if (f.exists()) {
            f.delete()
            f.createNewFile()
        }
        f.append(ont.toString())

    }


    String getInitial(String str) {
        String initial = ""

        String[] s = str.split(" ")
        s.each {
            initial += it.trim()[0]
        }
        return initial
    }


    void createOntologyInsert(String insertScript) {

        StringBuffer sb = new StringBuffer()

        ontology.each { k, v ->
            log.info "$v \t $k"
            String[] str = v.split("\\|")
            sb.append(createInsertRecord(str[1], k, str[3], str[0], str[2]))
        }

        // insert statements
        File f1 = new File(insertScript)
        if (f1.exists()) {
            f1.delete()
            f1.createNewFile()
        }
        f1.append(sb.toString())

        //return sb
    }

/**
 *  create insert statement for each ontology nodes
 *
 * @param hlevel
 * @param fullname
 * @param name
 * @param visualAttribute
 * @param basecode
 * @return
 */
    String createInsertRecord(String hlevel, String fullname, String name, String visualAttribute, basecode) {

        String stmt = ""

        stmt = "INSERT INTO TDI_ONTOLOGY(C_HLEVEL, C_FULLNAME, C_NAME, C_SYNONYM_CD, \n"
        stmt += "     C_VISUALATTRIBUTES, C_TOTALNUM, C_BASECODE, C_METADATAXML, \n"
        stmt += "     C_FACTTABLECOLUMN, C_TABLENAME, C_COLUMNNAME, C_COLUMNDATATYPE, \n"
        stmt += "     C_OPERATOR, C_DIMCODE, C_COMMENT, C_TOOLTIP,  \n"
        stmt += "     UPDATE_DATE, DOWNLOAD_DATE, IMPORT_DATE, SOURCESYSTEM_CD, VALUETYPE_CD) \n"
        stmt += "VALUES($hlevel, '$fullname', '$name', 'N', '$visualAttribute', 0, '$basecode', null, \n"
        stmt += "     'concelpt_cd', 'concept_dimension', 'concept_path', 'T', \n"
        stmt += "     'LIKE', '$fullname', null, '$fullname',  \n"
        stmt += "      getdate(), getdate(), getdate(), null, null)  \n\n"

        return stmt
    }

/**  get String value of a cell
 *
 * @param cell a spreadsheet cell
 * @return string value of a cell
 */
    String getCellStringValue(Cell cell) {
        String str = ""
        try {
            str = cell.getStringCellValue().replace("'", "''")
        } catch (Exception e) {
            str = cell.getNumericCellValue()
        }

        return str
    }

}


