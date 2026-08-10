CREATE OR REPLACE PROCEDURE sys.MANAGE_TBLSPACE AS 
-- directory of the default tablespace for OP user 
DIR sys.dba_data_files.file_name%TYPE; 
UND sys.dba_data_files.file_name%TYPE; 
TUNDO sys.dba_data_files.tablespace_name%TYPE; 
VUNDO varchar2(4000); 
TINDX sys.dba_data_files.tablespace_name%TYPE; 
-- name of the default_tablespace for OP user 
TBLSPACE sys.dba_data_files.tablespace_name%TYPE; 
WHAT_OS varchar2(50); 
 
cursor CUR1 is 
select default_tablespace from dba_users where username='OP';
cursor CUR2 is 
select tablespace_name from dba_data_files where tablespace_name='INDXUP'; 
cursor CUR3 is 
select tablespace_name from dba_data_files where tablespace_name='UNDOUP'; 
cursor CUR4 is 
select value from v$parameter where name='undo_tablespace'; 
 
 
REQ1 varchar2(200) := 'create tablespace INDXUP datafile '''; 
REQ2 varchar2(200) := 'alter tablespace '; 
 
REQ5_UNIX varchar2(200) := 'select substr(file_name,1,(instr(file_name,''/'',-1))) from sys.dba_data_files where tablespace_name=:1'; 
REQ5_DOS varchar2(200) := 'select substr(file_name,1,(instr(file_name,''\'',-1))) from sys.dba_data_files where tablespace_name=:1'; 
begin 
 
open CUR1; 
open CUR2; 
open CUR3; 
open CUR4; 
fetch CUR1 into TBLSPACE; 
fetch CUR2 into TINDX; 
fetch CUR3 into TUNDO; 
fetch CUR4 into VUNDO; 
select rtrim(substr(replace(banner,'TNS for ',''),1,instr(replace(banner,'TNS for ',''),':')-1)) os into WHAT_OS from v$version where banner like 'TNS for %'; 
if VUNDO is NULL then 
 RAISE_APPLICATION_ERROR (-20001,'Parameter undo_tablespace does not exist'); 
 return; 
END IF; 
close CUR1; 
close CUR2; 
close CUR3; 
close CUR4; 
 
if WHAT_OS like 'Window' then 
execute immediate REQ5_DOS into DIR using TBLSPACE; 
else 
execute immediate REQ5_UNIX into DIR using TBLSPACE; 
END IF; 
 
UND := DIR||'UNDOUP.dbf'; 
DIR := DIR||'INDXUP.dbf'; 
 
if TINDX is NULL then 
 REQ1 := REQ1||DIR||''' size 200M autoextend on next 50M'; 
 dbms_output.put_line('Create indxup file on: '||REQ1); 
 execute immediate REQ1; 
END IF; 

REQ2 := REQ2||VUNDO||' add datafile '''||UND||''' size 1G autoextend on next 100M'; 
 dbms_output.put_line('Create UNDOUP file on: '||REQ2); 
 execute immediate REQ2; 
end; 
/