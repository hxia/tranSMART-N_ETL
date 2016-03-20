CREATE OR REPLACE PROCEDURE "TM_CZ"."PARSE_NTH_VALUE" (varchar(1000), int4, varchar(4))
returns varchar(1000)
LANGUAGE NZPLSQL 
AS 
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
Declare
	pValue alias for $1;
	location alias for $2;
	delimiter alias for $3;
	
   v_posA int4;
   v_posB int4;
begin

   if location = 1 then
      v_posA := 1; -- Start at the beginning
   else
      v_posA := instr (pValue, delimiter, 1, location - 1); 
      if v_posA = 0 then
         return null; --No values left.
      end if;
      v_posA := v_posA + length(delimiter);
   end if;

   v_posB := instr (pValue, delimiter, 1, location);
   if v_posB = 0 then -- Use the end of the file
      return substr (pValue, v_posA);
   end if;
   
   return substr (pValue, v_posA, v_posB - v_posA);

end;
end_proc;
