create or replace procedure tm_cz.IS_DATE(
 varchar(ANY),VARCHAR(ANY)
)
RETURNS NUMERIC
LANGUAGE NZPLSQL AS
BEGIN_PROC
/*************************************************************************
* Copyright 2008-2012 Janssen Research & Development, LLC.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
******************************************************************/
DECLARE
	i_date		ALIAS FOR $1;
	i_format	alias for $2;
	
	P_STRING	VARCHAR(100);
	D_FMT		VARCHAR(100);
	
	v_timestamp	timestamp;
	
BEGIN
    -- x_date date;
	d_fmt := case when i_format is null or i_format = '' then 'YYYYMMDD' else i_format end;

	v_timestamp := to_date(i_date,d_fmt);
		
    return 0;
  exception
       when others then
           return 1;

   

END;

END_PROC;
   