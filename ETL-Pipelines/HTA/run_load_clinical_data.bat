rem *************************************************************************
rem  Copyright 2008-2012 Janssen Research & Development, LLC.
rem 
rem  Licensed under the Apache License, Version 2.0 (the "License");
rem  you may not use this file except in compliance with the License.
rem  You may obtain a copy of the License at
rem 
rem  http://www.apache.org/licenses/LICENSE-2.0
rem 
rem  Unless required by applicable law or agreed to in writing, software
rem  distributed under the License is distributed on an "AS IS" BASIS,
rem  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
rem  See the License for the specific language governing permissions and
rem  limitations under the License.
rem *****************************************************************/
echo on
set studyId=%1
set dataLocation=%2
set columnMap=%3
set wordMap=%4
set recExcl=%5
set topNode=%6
rem if either KETTLE_HOME or KETTLE_DIR folder contains spaces, enclose the value in double quotes (")
set KETTLE_HOME=C:\Users\javitabile\Documents\tranSMART-GPL_1.1
set KETTLE_DIR=C:\Users\javitabile\Documents\Kettle-4.4\data-integration
SET HOUR=%time:~0,2%
SET dtStamp9=%date:~-4%%date:~4,2%%date:~7,2%_0%time:~1,1%%time:~3,2%%time:~6,2% 
SET dtStamp24=%date:~-4%%date:~4,2%%date:~7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
if "%HOUR:~0,1%" == " " (SET dtStamp=%dtStamp9%) else (SET dtStamp=%dtStamp24%)
rem trim trailing spaces
set dtStamp=%dtStamp:~0,15%
%KETTLE_DIR%\kitchen.bat /rep:1 /dir="/DSE" /job:"ETL.clinical.create_clinical_data" /user:admin /pass:admin ^
-param:COLUMN_MAP_FILE=%columnMap% ^
-param:DATA_LOCATION=%dataLocation%  ^
-param:HIGHLIGHT_STUDY=N ^
-param:LOAD_TYPE=L ^
-param:RECORD_EXCLUSION_FILE=%recExcl% ^
-param:SECURITY_REQUIRED=N ^
-param:SORT_DIR=%KETTLE_DIR% ^
-param:STUDY_ID=%studyId% ^
-param:TOP_NODE=%topNode%  ^
-param:WORD_MAP_FILE=%wordMap%

rem NOTE NOTE NOTE
rem TOP_NODE must end with \\ because of Windows escape handling
rem -log=%dataLocation%\load_clinical_data_%dtStamp%.log ^
exit /b