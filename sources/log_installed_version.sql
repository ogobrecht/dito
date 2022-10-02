declare
  v_count   pls_integer;
  v_version varchar2(10 byte);
begin
  select count(*)
    into v_count
    from user_errors
   where name = 'DITO';
  if v_count = 0 then
    -- without execute immediate this script will raise an error when the package dito is not valid
    execute immediate 'select dito.version from dual' into v_version;
    dbms_output.put_line('- FINISHED: v' || v_version);
  end if;
end;
/
prompt


