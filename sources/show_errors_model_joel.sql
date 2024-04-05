-- check for errors in package model_joel
declare
  l_count pls_integer;
begin
  select count(*)
    into l_count
    from user_errors
   where name = 'MODEL_JOEL';
  if l_count > 0 then
    dbms_output.put_line('- Package MODEL_JOEL has errors :-(');
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
 where name = 'MODEL_JOEL'
 order by name, line, position;
