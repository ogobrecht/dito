-- check for errors in package model
declare
  l_count pls_integer;
  l_name  varchar2(30) := 'MODEL';
begin
  select count(*)
    into l_count
    from user_errors
   where name = l_name;
  if l_count > 0 then
    dbms_output.put_line('- Package ' || l_name || ' has errors :-(');
    for i in (
        select name || case when type like '%BODY' then ' body' end || ', ' ||
               'line ' || line || ', ' ||
               'column ' || position || ', ' ||
               attribute  || ': ' ||
               text as message
          from user_errors
         where name = l_name
         order by name, line, position )
    loop
        dbms_output.put_line('- ' || i.message);
    end loop;
  end if;
end;
/
