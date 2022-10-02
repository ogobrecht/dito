--DO NOT CHANGE THIS FILE - IT IS GENERATED WITH THE BUILD SCRIPT build.js
set define on
set serveroutput on
set verify off
set feedback off
set linesize 240
set trimout on
set trimspool on
whenever sqlerror exit sql.sqlcode rollback

prompt ORACLE DICTIONARY TOOLS: CREATE DATABASE OBJECTS
prompt - Project page https://github.com/ogobrecht/dito
-- select * from all_plsql_object_settings where name = 'DITO';

prompt - Set compiler flags
declare
  v_apex_installed     varchar2(5) := 'FALSE'; -- Do not change (is set dynamically).
  v_utils_public       varchar2(5) := 'FALSE'; -- Make utilities public available (for testing or other usages).
  v_native_compilation boolean     := false;   -- Set this to true on your own risk (in the Oracle cloud you will get likely an "insufficient privileges" error)
  v_count pls_integer;
begin

  execute immediate 'alter session set plsql_warnings = ''enable:all,disable:5004,disable:6005,disable:6006,disable:6009,disable:6010,disable:6027,disable:7207''';
  execute immediate 'alter session set plscope_settings = ''identifiers:all''';
  execute immediate 'alter session set plsql_optimize_level = 3';

  if v_native_compilation then
    execute immediate 'alter session set plsql_code_type=''native''';
  end if;

  select count(*) into v_count from all_objects where object_type = 'SYNONYM' and object_name = 'APEX_EXPORT';
  v_apex_installed := case when v_count = 0 then 'FALSE' else 'TRUE' end;

  execute immediate 'alter session set plsql_ccflags = '''
    || 'APEX_INSTALLED:' || v_apex_installed || ','
    || 'UTILS_PUBLIC:'   || v_utils_public   || '''';

end;
/

prompt - Package DITO (spec)
create or replace package dito authid current_user is

c_name    constant varchar2 ( 30 byte ) := 'Oracle Dictionary Tools'           ;
c_version constant varchar2 ( 10 byte ) := '0.5.0'                             ;
c_url     constant varchar2 ( 34 byte ) := 'https://github.com/ogobrecht/dito' ;
c_license constant varchar2 (  3 byte ) := 'MIT'                               ;
c_author  constant varchar2 ( 15 byte ) := 'Ottmar Gobrecht'                   ;

c_dict_tabs_list constant varchar2 (1000 byte) := '
  user_tables         ,
  user_tab_columns    ,
  user_constraints    ,
  user_cons_columns   ,
  user_indexes        ,
  user_ind_columns    ,
  user_tab_comments   ,
  user_mview_comments ,
  user_col_comments   ,
  all_tables          ,
  all_tab_columns     ,
  all_constraints     ,
  all_cons_columns    ,
  all_indexes         ,
  all_ind_columns     ,
  all_tab_comments    ,
  all_mview_comments  ,
  all_col_comments    ,
';

/**

Oracle Dictionary Tools
=======================

PL/SQL tools for the Oracle DB dictionary views...

This project is in an early stage - use it at your own risk...

CHANGELOG

- 0.5.0 (2022-10-02): Rename package from MODEL to DITO (for DIctionary TOols), rework project structure
- 0.4.0 (2022-03-05): New methods get_table_query and get_table_headers
- 0.3.0 (2021-10-28): New helper methods get_data_default_vc, get_search_condition_vc
- 0.2.1 (2021-10-24): Fix error on unknown tables, add elapsed time to output, reformat code
- 0.2.0 (2021-10-23): Add a param for custom tab lists, improved docs
- 0.1.0 (2021-10-22): Initial minimal version

**/

--------------------------------------------------------------------------------
-- PUBLIC SIMPLE TYPES
--------------------------------------------------------------------------------

subtype t_int  is pls_integer;
subtype t_1b   is varchar2 (    1 byte);
subtype t_2b   is varchar2 (    2 byte);
subtype t_4b   is varchar2 (    4 byte);
subtype t_8b   is varchar2 (    8 byte);
subtype t_16b  is varchar2 (   16 byte);
subtype t_32b  is varchar2 (   32 byte);
subtype t_64b  is varchar2 (   64 byte);
subtype t_128b is varchar2 (  128 byte);
subtype t_256b is varchar2 (  256 byte);
subtype t_512b is varchar2 (  512 byte);
subtype t_1kb  is varchar2 ( 1024 byte);
subtype t_2kb  is varchar2 ( 2048 byte);
subtype t_4kb  is varchar2 ( 4096 byte);
subtype t_8kb  is varchar2 ( 8192 byte);
subtype t_16kb is varchar2 (16384 byte);
subtype t_32kb is varchar2 (32767 byte);

--------------------------------------------------------------------------------
-- PUBLIC DITO METHODS
--------------------------------------------------------------------------------

procedure create_dict_mviews (
  p_dict_tabs_list in varchar2 default c_dict_tabs_list );
/**

Create materialized views for data dictionary tables.

The mviews are named like `table_name` + `_mv`.

Per default only mviews for some user_xxx tables are created - also see
`c_dict_tabs_list` in package signature above.

You can overwrite the default by provide your own data dictionary table list:

EXAMPLES

```sql
-- log is written to serveroutput, so we enable it here
set serveroutput on

-- with default data dictionary table list
exec dito.create_dict_mviews;

-- with custom data dictionary table list
exec dito.create_dict_mviews('all_tables, all_tab_columns');

-- works also when you provide the resulting mviev names instead
-- of the table names or when you have line breaks in your list
begin
  dito.create_dict_mviews('
    all_tables_mv       ,
    all_tab_columns_mv  ,
    all_constraints_mv  ,
    all_cons_columns_mv ,
  ');
end;
{{/}}
```

**/

--------------------------------------------------------------------------------

procedure refresh_dict_mviews (
  p_dict_tabs_list in varchar2 default c_dict_tabs_list );
/**

Refresh the materialized views.

Same rules and defaults as for the `create_dict_mviews` method (see above).

If you created a custum set of mviews you should provide the same parameter
value here for the refresh.

**/

--------------------------------------------------------------------------------

procedure drop_dict_mviews (
  p_dict_tabs_list in varchar2 default c_dict_tabs_list );
/**

Drop the materialized views.

Same rules and defaults as for the `create_dict_mviews` method (see above).

If you created a custum set of mviews you should provide the same parameter
value here for the drop.

**/

--------------------------------------------------------------------------------

function get_data_default_vc (
  p_dict_tab_name in varchar2,
  p_table_name    in varchar2,
  p_column_name   in varchar2,
  p_owner         in varchar2 default user )
 return varchar2;
/**

Convert the LONG column DATA_DEFAULT to varchar2(4000).

Is used in `create_dict_mviews`. Works only for the dictionary tables
USER_TAB_COLUMNS, USER_TAB_COLS, ALL_TAB_COLUMNS, ALL_TAB_COLS,
USER_NESTED_TABLE_COLS, ALL_NESTED_TABLE_COLS.

**/

--------------------------------------------------------------------------------

function get_search_condition_vc (
  p_dict_tab_name   in varchar2,
  p_constraint_name in varchar2,
  p_owner           in varchar2 default user )
  return varchar2;
/**

Convert the LONG column SEARCH_CONDITION to varchar2(4000).

Is used in `create_dict_mviews`. Works only for the dictionary_tables
USER_CONSTRAINTS, ALL_CONSTRAINTS

**/

--------------------------------------------------------------------------------

function get_table_query (
  p_table_name  in varchar2,
  p_schema_name in varchar2 default sys_context('USERENV', 'CURRENT_USER') )
  return varchar2;
/**

Get the query for a given table.

**/

--------------------------------------------------------------------------------

function get_table_headers (
  p_table_name  in varchar2,
  p_schema_name in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
  p_delimiter   in varchar2 default ':',
  p_lowercase   in boolean  default true )
  return varchar2;
/**

Get the column headings for a given table as a delimited string.

**/

/*
function get_table_heads_generic_cols (
  p_table_name in varchar2 ,
  p_delimiter  in varchar2 default ':',
  p_lowercase  in boolean  default true )
  return varchar2;

Get the generic column headers for a given table as a delimited string .

*/

--------------------------------------------------------------------------------

function version return varchar2;
/**

Returns the version information from the dito package.

Inspired by [Steven's Live SQL example](https://livesql.oracle.com/apex/livesql/file/content_CBXGUSXSVIPRVUPZGJ0HGFQI0.html)

```sql
select dito.version from dual;
```

**/

--------------------------------------------------------------------------------

end dito;
/

prompt - Package DITO (body)
create or replace package body dito is

--------------------------------------------------------------------------------

function utl_cleanup_tabs_list (
  p_tabs_list in varchar2 )
  return varchar2
is
begin
  return trim(both ',' from regexp_replace(regexp_replace(p_tabs_list, '\s+'), ',{2,}', ','));
end;

--------------------------------------------------------------------------------

function runtime (
  p_start in timestamp )
  return varchar2
is
  v_runtime t_32b;
begin
  v_runtime := to_char(localtimestamp - p_start);
  return substr(v_runtime, instr(v_runtime,':')-2, 15);
end runtime;

--------------------------------------------------------------------------------

function utl_runtime_seconds (
  p_start in timestamp )
  return number
is
  v_runtime interval day to second;
begin
  v_runtime := localtimestamp - p_start;
  return
    extract(hour   from v_runtime) * 3600 +
    extract(minute from v_runtime) *   60 +
    extract(second from v_runtime)        ;
end utl_runtime_seconds;

--------------------------------------------------------------------------------

function utl_create_dict_mview (
  p_table_name in varchar2 )
  return integer
is
  v_table_name t_1kb;
  v_mview_name t_1kb;
  v_sql        t_32kb;
  v_return     t_int := 0;
begin
  v_table_name := lower(trim(substr(p_table_name, 1, 1000)));
  v_mview_name := v_table_name || '_mv';
  for i in (
    with base as (
      select table_name, column_name, data_type, data_length
        from all_tab_cols
       where owner = 'SYS'
         and table_name = upper(v_table_name)
       order by column_id
    )
    select table_name,
           column_name,
           data_type,
           data_length,
           case when data_type = 'LONG' then (
             select count(*)
               from base
              where column_name = t.column_name || '_VC')
           end as vc_column_exists
      from base t
  )
  loop
    v_sql := v_sql || '  ' ||
      case when i.data_type != 'LONG' then
        lower(i.column_name) || ',' || chr(10)
        else
          'to_lob(' || lower(i.column_name) || ') as ' || lower(i.column_name) || ',' || chr(10) ||
          case when i.vc_column_exists = 0 then
            case i.column_name
              when 'DATA_DEFAULT' then
                '  case when data_default is not null then dito.get_data_default_vc(p_dict_tab_name=>''' || v_table_name ||
                  ''',p_table_name=>table_name,p_column_name=>column_name' ||
                  case when v_table_name like 'all%' then ',p_owner=>owner' end ||
                  ') end as ' || lower(i.column_name) || '_vc,' || chr(10)
              when 'SEARCH_CONDITION' then
                '  case when search_condition is not null then dito.get_search_conditions_vc(p_dict_tab_name=>''' || v_table_name ||
                  ''',p_table_name=>table_name,p_constraint_name=>constraint_name,p_owner=>owner' ||
                  ') end as ' || lower(i.column_name) || '_vc,' || chr(10)
            end
          end
      end;
  end loop;
  if v_sql is not null then
    v_return := 1;
    v_sql    := 'create materialized view ' || v_mview_name || ' as ' || chr(10) ||
                    'select'                                          || chr(10) ||
                    rtrim(v_sql, ',' || chr(10))                      || chr(10) ||
                    'from'                                            || chr(10) ||
                    '  ' || v_table_name;
    --dbms_output.put_line(v_sql);
    dbms_output.put_line('- ' || v_mview_name);
    execute immediate(v_sql);
  end if;
  return v_return;
end utl_create_dict_mview;

--------------------------------------------------------------------------------

procedure create_dict_mviews (
  p_dict_tabs_list in varchar2 default c_dict_tabs_list )
is
  v_start          timestamp := localtimestamp;
  v_dict_tabs_list t_32kb    := utl_cleanup_tabs_list(p_dict_tabs_list);
  v_count          t_int     := 0;
begin
  dbms_output.put_line('DITO - CREATE DICT MVIEWS');
  for i in (
    -- https://blogs.oracle.com/sql/post/split-comma-separated-values-into-rows-in-oracle-database
    with
    base as ( select v_dict_tabs_list as str from dual ),
    tabs as (
       select regexp_replace(upper(trim(regexp_substr(str, '[^,]+', 1, level))), '_MV$') as table_name
         from base
      connect by level <= length(str) - length(replace(str, ',')) + 1
    )
    select table_name from tabs
    minus
    select regexp_replace(mview_name, '_MV$') from user_mviews where regexp_like (mview_name, '_MV$')
  )
  loop
    v_count := v_count + utl_create_dict_mview(i.table_name);
  end loop;
  dbms_output.put_line('- ' || v_count || ' mview' || case when v_count != 1 then 's' end || ' created in ' || runtime(v_start));

end create_dict_mviews;

--------------------------------------------------------------------------------

procedure refresh_dict_mviews (
  p_dict_tabs_list in varchar2 default c_dict_tabs_list )
is
  v_start          timestamp := localtimestamp;
  v_dict_tabs_list t_32kb    := utl_cleanup_tabs_list(p_dict_tabs_list);
  v_count          t_int     := 0;
begin
  dbms_output.put_line('DITO - REFRESH DICT MVIEWS');
  for i in (
    with
    base as ( select v_dict_tabs_list as str from dual ),
    tabs as (
       select regexp_replace(upper(trim(regexp_substr(str, '[^,]+', 1, level))), '_MV$') as table_name
         from base
      connect by level <= length(str) - length(replace(str, ',')) + 1
    ),
    expected_mviews as ( select table_name || '_MV' as mview_name from tabs )
    select mview_name from expected_mviews natural join user_mviews
  )
  loop
    dbms_output.put_line('- ' || lower(i.mview_name));
    dbms_mview.refresh(list => i.mview_name, method => 'c');
    v_count := v_count + 1;
  end loop;
  dbms_output.put_line('- ' || v_count || ' mview' || case when v_count != 1 then 's' end || ' refreshed in ' || runtime(v_start));
end refresh_dict_mviews;

--------------------------------------------------------------------------------

procedure drop_dict_mviews (
  p_dict_tabs_list in varchar2 default c_dict_tabs_list )
is
  v_start          timestamp := localtimestamp;
  v_dict_tabs_list t_32kb    := utl_cleanup_tabs_list(p_dict_tabs_list);
  v_count          t_int     := 0;
begin
  dbms_output.put_line('DITO - DROP DICT MVIEWS');
  for i in(
    with
    base as ( select v_dict_tabs_list as str from dual ),
    tabs as (
       select regexp_replace(upper(trim(regexp_substr(str, '[^,]+', 1, level))), '_MV$') as table_name
         from base
      connect by level <= length(str) - length(replace(str, ',')) + 1
    ),
    expected_mviews as ( select table_name || '_MV' as table_name from tabs )
    select mview_name from expected_mviews join user_mviews on table_name = mview_name )
  loop
    dbms_output.put_line('- ' || lower(i.mview_name));
    execute immediate 'drop materialized view ' || i.mview_name;
    v_count := v_count + 1;
  end loop;
  dbms_output.put_line('- ' || v_count || ' mview' || case when v_count != 1 then 's' end || ' dropped in ' || runtime(v_start));
end drop_dict_mviews;

--------------------------------------------------------------------------------

function get_data_default_vc (
  p_dict_tab_name varchar2,
  p_table_name    varchar2,
  p_column_name   varchar2,
  p_owner         varchar2 default user)
  return varchar2
is
  v_long long;
begin
  case
    when upper(p_dict_tab_name) in ('USER_TAB_COLUMNS', 'USER_TAB_COLS') then
      select data_default into v_long
        from user_tab_columns
       where table_name = upper(p_table_name)
         and column_name = upper(p_column_name);
    when upper(p_dict_tab_name) in ('ALL_TAB_COLUMNS', 'ALL_TAB_COLS') then
      select data_default into v_long
        from all_tab_columns
       where owner = p_owner
         and table_name = upper(p_table_name)
         and column_name = upper(p_column_name);
    when upper(p_dict_tab_name) = 'USER_NESTED_TABLE_COLS' then
      select data_default into v_long
        from user_nested_table_cols
       where table_name = upper(p_table_name)
         and column_name = upper(p_column_name);
    when upper(p_dict_tab_name) = 'ALL_NESTED_TABLE_COLS' then
      select data_default into v_long
        from all_nested_table_cols
       where owner = p_owner
         and table_name = upper(p_table_name)
         and column_name = upper(p_column_name);
    else
      raise_application_error(-20999, 'Unsupported dictionary table ' || p_dict_tab_name);
  end case;
  return substr(v_long, 1, 4000);
end get_data_default_vc;

--------------------------------------------------------------------------------

function get_search_condition_vc (
  p_dict_tab_name   in varchar2,
  p_constraint_name in varchar2,
  p_owner           in varchar2 default user )
  return varchar2
is
  v_long long;
begin
  case upper(p_dict_tab_name)
    when 'USER_CONSTRAINTS' then
      select search_condition into v_long
        from user_constraints
       where owner = p_owner
         and constraint_name = upper(p_constraint_name);
    when 'ALL_CONSTRAINTS' then
      select search_condition into v_long
        from all_constraints
       where owner = p_owner
         and constraint_name = upper(p_constraint_name);
    else
      raise_application_error(-20999, 'Unsupported dictionary table ' || p_dict_tab_name);
  end case;
  return substr(v_long, 1, 4000);
end get_search_condition_vc;

--------------------------------------------------------------------------------

function get_table_query (
  p_table_name  in varchar2,
  p_schema_name in varchar2 default sys_context('USERENV', 'CURRENT_USER') )
  return varchar2
is
  v_return varchar2( 32767 ) := 'select ';
begin
  for i in ( select *
               from all_tab_columns
              where owner      = p_schema_name
                and table_name = p_table_name
              order by column_id )
  loop
    v_return := v_return || i.column_name || ', ';
  end loop;

  return rtrim( v_return, ', ' ) || ' from ' || p_table_name;
end get_table_query;

--------------------------------------------------------------------------------

function get_table_headers (
  p_table_name  in varchar2,
  p_schema_name in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
  p_delimiter   in varchar2 default ':',
  p_lowercase   in boolean  default true )
  return varchar2
is
  v_return varchar2(32767);
begin
  for i in ( select *
               from all_tab_columns
              where owner      = p_schema_name
                and table_name = p_table_name
              order by column_id )
  loop
    v_return := v_return ||
                case
                  when p_lowercase
                  then lower( i.column_name )
                  else i.column_name
                end ||
                p_delimiter;
  end loop;

  return rtrim( v_return, p_delimiter );
end get_table_headers;

--------------------------------------------------------------------------------

function version return varchar2 is
begin
  return c_version;
end version;

--------------------------------------------------------------------------------

end dito;
/
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




