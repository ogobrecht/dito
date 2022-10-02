set define on
set serveroutput on
set verify off
set feedback off
set linesize 240
set trimout on
set trimspool on
whenever sqlerror exit sql.sqlcode rollback

prompt ORACLE DICTIONARY TOOLS: DROP DATABASE OBJECTS

declare
  v_count        pls_integer;
  v_object_count pls_integer := 0;
  v_ddl          varchar2 (100);
begin

  --package body
  for i in (
    select 'drop ' || lower(object_type) || ' ' || object_name as ddl
      from user_objects
     where object_type = 'PACKAGE BODY'
       and object_name = 'DITO'
  ) loop
    dbms_output.put_line('- ' || i.ddl || ';');
    execute immediate i.ddl;
    v_object_count := v_object_count + 1;
  end loop;

  --package spec
  for i in (
    select 'drop ' || lower(object_type) || ' ' || object_name as ddl
      from user_objects
     where object_type = 'PACKAGE'
       and object_name = 'DITO'
  ) loop
    dbms_output.put_line('- ' || i.ddl || ';');
    execute immediate i.ddl;
    v_object_count := v_object_count + 1;
  end loop;

  dbms_output.put_line('- ' || v_object_count || ' object' || case when v_object_count != 1 then 's' end || ' dropped');

end;
/

prompt - FINISHED
