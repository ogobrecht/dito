-- check for errors in package dito
declare
  v_count pls_integer;
begin
  select count(*)
    into v_count
    from user_errors
   where name = 'DITO';
  if v_count > 0 then
    dbms_output.put_line('- Package DITO has errors :-(');
  end if;
end;
/

column "Name"      format a15
column "Line,Col"  format a10
column "Type"      format a10
column "Message"   format a80

select name || case when type like '%BODY' then ' body' end as "Name",
       line || ',' || position as "Line,Col",
       attribute               as "Type",
       text                    as "Message"
  from user_errors
 where name = 'DITO'
 order by name, line, position;
