declare
  v_count   pls_integer;
  v_version varchar2(10 byte);
begin
  select count(*)
    into v_count
    from user_errors
   where name = 'MODEL';
  if v_count = 0 then
    -- without execute immediate this script will raise an error when the package model is not valid
    execute immediate 'select model.version from dual' into v_version;
    dbms_output.put_line('- FINISHED (v' || v_version || ')');
  end if;
end;
/
prompt


