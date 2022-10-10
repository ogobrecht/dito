--DO NOT CHANGE THIS FILE - IT IS GENERATED WITH THE BUILD SCRIPT build.js
set define on
set serveroutput on
set verify off
set feedback off
set linesize 240
set trimout on
set trimspool on
whenever sqlerror exit sql.sqlcode rollback

exec model.create_dict_mviews('all_tab_columns');
prompt
prompt ORACLE DATA MODEL UTILITIES - CREATE APEX EXTENSION PACKAGE
prompt - Project page https://github.com/ogobrecht/model
-- select * from all_plsql_object_settings where name = 'MODEL';

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

prompt - Package model_joel (spec)
create or replace package model_joel authid current_user is

/**

Oracle Data Model Utilities - APEX Extension
============================================

Helpers to support a generic Interactive Report to show the data any table.

**/

function get_table_query_apex (
    p_table_name             in varchar2,
    p_schema_name            in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
    p_max_cols_number        in integer default 20,
    p_max_cols_date          in integer default  5,
    p_max_cols_timestamp_ltz in integer default  5,
    p_max_cols_timestamp_tz  in integer default  5,
    p_max_cols_timestamp     in integer default  5,
    p_max_cols_varchar       in integer default 20,
    p_max_cols_clob          in integer default  5 )
    return varchar2;
/**

Get the query for a given table.

This prepares also APEX session state for the conditional display of generic
columns.

EXAMPLE

```sql
select model_joel.get_table_query(p_table_name => 'CONSOLE_LOGS')
  from dual;
```

**/

procedure create_application_items (
    p_app_id                 in integer,
    p_max_cols_number        in integer default 20,
    p_max_cols_varchar       in integer default 20,
    p_max_cols_clob          in integer default  5,
    p_max_cols_date          in integer default  5,
    p_max_cols_timestamp     in integer default  5,
    p_max_cols_timestamp_tz  in integer default  5,
    p_max_cols_timestamp_ltz in integer default  5 );
/**

Create application items for the generic report to control which columns to
show and what the headers are.

This procedure needs an APEX session to work and the application needs to be
runtime modifiable. This cn be set under: Shared Components > Security
Attributes > Runtime API Usage > Check "Modify This Application".

EXAMPLE

```sql
-- in a script with defaults
exec apex_session.create_session(100, 1, 'MY_USER');
exec model_joel.create_application_items(100);

-- with custom settings
begin
    apex_session.create_session (
        p_app_id   => 100,
        p_page_id  => 1,
        p_username => 'MY_USER' );

    model_joel.create_application_items (
        p_app_id                 => 100,
        p_max_cols_number        =>  40,
        p_max_cols_date          =>  10,
        p_max_cols_timestamp_ltz =>  10,
        p_max_cols_timestamp_tz  =>  10,
        p_max_cols_timestamp     =>  10,
        p_max_cols_varchar       =>  40,
        p_max_cols_clob          =>  10 );
end;
{{/}}
```

**/

--------------------------------------------------------------------------------

end model_joel;
/

prompt - Package model_joel (body)
create or replace package body model_joel is

--------------------------------------------------------------------------------

function get_table_query_apex (
    p_table_name             in varchar2,
    p_schema_name            in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
    p_max_cols_number        in integer default 20,
    p_max_cols_date          in integer default  5,
    p_max_cols_timestamp_ltz in integer default  5,
    p_max_cols_timestamp_tz  in integer default  5,
    p_max_cols_timestamp     in integer default  5,
    p_max_cols_varchar       in integer default 20,
    p_max_cols_clob          in integer default  5 )
    return varchar2
is
    v_return            varchar2(32767);
    v_column_expression varchar2(200);
    v_generic_column    varchar2(30);
    v_sep               varchar2(2) := ',' || chr(10);
    v_column_indent     varchar2(7) := '       ';
    v_table_exists      boolean     := false;
    v_count_n           pls_integer := 0;
    v_count_vc          pls_integer := 0;
    v_count_clob        pls_integer := 0;
    v_count_d           pls_integer := 0;
    v_count_ts          pls_integer := 0;
    v_count_tstz        pls_integer := 0;
    v_count_tsltz       pls_integer := 0;

    ----------------------------------------

    procedure process_table_columns
    is
        v_column_included boolean;
    begin
        for i in (
            select
                column_name,
                data_type
            from
                all_tab_columns_mv
            where
                owner = p_schema_name
                and table_name = p_table_name
            order by
                column_id )
        loop
            v_table_exists    := true;
            v_column_included := true;
            case
                when i.data_type in ('NUMBER', 'FLOAT') and v_count_n < p_max_cols_number then
                    v_count_n           := v_count_n + 1;
                    v_column_expression := i.column_name;
                    v_generic_column    := 'N' || lpad(to_char(v_count_n), 3, '0');

                when i.data_type = 'DATE' and v_count_d < p_max_cols_date then
                    v_count_d           := v_count_d + 1;
                    v_column_expression := i.column_name;
                    v_generic_column    := 'D' || lpad(to_char(v_count_d), 3, '0');

                when i.data_type like 'TIMESTAMP% WITH LOCAL TIME ZONE' and v_count_tsltz < p_max_cols_timestamp_ltz then
                    v_count_tsltz       := v_count_tsltz + 1;
                    v_column_expression := i.column_name;
                    v_generic_column    := 'TSLTZ' || lpad(to_char(v_count_tsltz), 3, '0');

                when i.data_type like 'TIMESTAMP% WITH TIME ZONE' and v_count_tstz < p_max_cols_timestamp_tz then
                    v_count_tstz        := v_count_tstz + 1;
                    v_column_expression := i.column_name;
                    v_generic_column    := 'TSTZ' || lpad(to_char(v_count_tstz), 3, '0');

                when i.data_type like 'TIMESTAMP%' and v_count_ts < p_max_cols_timestamp then
                    v_count_ts          := v_count_ts + 1;
                    v_column_expression := i.column_name;
                    v_generic_column    := 'TS' || lpad(to_char(v_count_ts), 3, '0');

                when i.data_type in ('CHAR', 'VARCHAR2') and v_count_vc < p_max_cols_varchar then
                    v_count_vc          := v_count_vc + 1;
                    v_column_expression := i.column_name;
                    v_generic_column    := 'VC' || lpad(to_char(v_count_vc), 3, '0');

                when i.data_type = 'CLOB' and v_count_clob < p_max_cols_clob then
                    v_count_clob        := v_count_clob + 1;
                    v_column_expression := 'substr(' || i.column_name || ', 1, 4000)';
                    v_generic_column    := 'CLOB' || lpad(to_char(v_count_clob), 3, '0');

                else
                    v_column_included := false;
            end case;

            if v_column_included then
                v_return := v_return
                    || v_column_indent || v_column_expression
                    || ' as ' || v_generic_column || v_sep;
            end if;

            apex_util.set_session_state (
                p_name  => v_generic_column,
                p_value => initcap(replace(i.column_name, '_', ' ')) );
        end loop;
    end process_table_columns;

    ----------------------------------------

    procedure fill_up_generic_columns (
        p_type in varchar2 )
    is
        v_count    pls_integer;
        v_max_cols pls_integer;
    begin
        v_count :=
            case p_type
                when 'N'     then v_count_n
                when 'D'     then v_count_d
                when 'TSLTZ' then v_count_tsltz
                when 'TSTZ'  then v_count_tstz
                when 'TS'    then v_count_ts
                when 'VC'    then v_count_vc
                when 'CLOB'  then v_count_clob
            end + 1;

        v_max_cols :=
            case p_type
                when 'N'     then p_max_cols_number
                when 'D'     then p_max_cols_date
                when 'TSLTZ' then p_max_cols_timestamp_ltz
                when 'TSTZ'  then p_max_cols_timestamp_tz
                when 'TS'    then p_max_cols_timestamp
                when 'VC'    then p_max_cols_varchar
                when 'CLOB'  then p_max_cols_clob
            end;

        for i in v_count .. v_max_cols loop
            v_generic_column := p_type || lpad(to_char(i), 3, '0');

            v_return         := v_return || v_column_indent ||
                                'null as ' || v_generic_column || v_sep;

            apex_util.set_session_state (
                p_name  => v_generic_column,
                p_value => null );
        end loop;
    end fill_up_generic_columns;

    ----------------------------------------

begin
    process_table_columns;

    fill_up_generic_columns(p_type => 'N'    );
    fill_up_generic_columns(p_type => 'D'    );
    fill_up_generic_columns(p_type => 'TSLTZ');
    fill_up_generic_columns(p_type => 'TSTZ' );
    fill_up_generic_columns(p_type => 'TS'   );
    fill_up_generic_columns(p_type => 'VC'   );
    fill_up_generic_columns(p_type => 'CLOB' );

    v_return :=    'select ' || rtrim( ltrim(v_return), v_sep ) || chr(10)
                || '  from ' || case when v_table_exists
                                    then p_schema_name || '.' || p_table_name
                                    else 'dual'
                                end;

    return v_return;
end get_table_query_apex;

--------------------------------------------------------------------------------

procedure create_application_items (
    p_app_id                 in integer,
    p_max_cols_number        in integer default 20,
    p_max_cols_varchar       in integer default 20,
    p_max_cols_clob          in integer default  5,
    p_max_cols_date          in integer default  5,
    p_max_cols_timestamp     in integer default  5,
    p_max_cols_timestamp_tz  in integer default  5,
    p_max_cols_timestamp_ltz in integer default  5 )
is
    v_app_items wwv_flow_global.vc_map;

    ----------------------------------------

    procedure create_items (
        p_type in varchar2 )
    is
        v_generic_column varchar2(30);
        v_max_cols       pls_integer;
        v_count_n        pls_integer := 0;
        v_count_vc       pls_integer := 0;
        v_count_clob     pls_integer := 0;
        v_count_d        pls_integer := 0;
        v_count_ts       pls_integer := 0;
        v_count_tstz     pls_integer := 0;
        v_count_tsltz    pls_integer := 0;
    begin
        v_max_cols :=
            case p_type
                when 'N'     then p_max_cols_number
                when 'D'     then p_max_cols_date
                when 'TSLTZ' then p_max_cols_timestamp_ltz
                when 'TSTZ'  then p_max_cols_timestamp_tz
                when 'TS'    then p_max_cols_timestamp
                when 'VC'    then p_max_cols_varchar
                when 'CLOB'  then p_max_cols_clob
            end;

        for i in 1 .. v_max_cols loop
            v_generic_column := p_type || lpad(to_char(i), 3, '0');

            if not v_app_items.exists(v_generic_column) then
                wwv_flow_imp_shared.create_flow_item (
                    p_flow_id          => p_app_id,
                    p_id               => wwv_flow_id.next_val,
                    p_name             => v_generic_column,
                    p_protection_level => 'I' );
            end if;

        end loop;
    end create_items;

    ----------------------------------------

begin
    -- prepare map
    for i in (
        select
            item_name
        from
            apex_application_items
        where
            application_id = p_app_id )
    loop
        v_app_items ( i.item_name ) := null; -- we need only the key
    end loop;

    -- create app items as needed
    create_items(p_type => 'N'    );
    create_items(p_type => 'D'    );
    create_items(p_type => 'TSLTZ');
    create_items(p_type => 'TSTZ' );
    create_items(p_type => 'TS'   );
    create_items(p_type => 'VC'   );
    create_items(p_type => 'CLOB' );

end create_application_items;

--------------------------------------------------------------------------------

end model_joel;
/
-- check for errors in package model_joel
declare
  v_count pls_integer;
begin
  select count(*)
    into v_count
    from user_errors
   where name = 'MODEL_JOEL';
  if v_count > 0 then
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

prompt - FINISHED

exec apex_session.create_session(103, 1, 'OGOBRECH');
exec model_joel.create_application_items(103);

