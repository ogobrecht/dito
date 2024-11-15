declare
  l_count   pls_integer;
  l_version varchar2(10 byte);
begin
  select count(*)
    into l_count
    from user_errors
   where name = 'MODEL';
  if l_count = 0 then
    -- without execute immediate this script will raise an error when the package model is not valid
    execute immediate 'select model.version from dual' into l_version;
    dbms_output.put_line('- Version: ' || l_version);
  end if;
end;
/