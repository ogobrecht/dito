--DO NOT CHANGE THIS FILE - IT IS GENERATED WITH THE BUILD SCRIPT build.js
set define on
set serveroutput on
set verify off
set feedback off
set linesize 240
set trimout on
set trimspool on
whenever sqlerror exit sql.sqlcode rollback

prompt CREATE OR REFRESH NEEDED MVIEW
exec model.create_or_refresh_mview('ALL_TAB_COLUMNS', 'SYS');
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

Helpers to support a generic Interactive Report to show the data of any
table.

**/

--------------------------------------------------------------------------------

function get_table_query (
    p_table_name             in varchar2              ,
    p_owner                  in varchar2 default sys_context('USERENV', 'CURRENT_USER') ,
    p_max_cols_number        in integer  default   20 ,
    p_max_cols_date          in integer  default    5 ,
    p_max_cols_timestamp_ltz in integer  default    5 ,
    p_max_cols_timestamp_tz  in integer  default    5 ,
    p_max_cols_timestamp     in integer  default    5 ,
    p_max_cols_varchar       in integer  default   20 ,
    p_max_cols_clob          in integer  default    5 )
    return clob;
/**

Get the query for a given table.

This prepares also APEX session state for the conditional display of generic
columns.

EXAMPLE

```sql
-- with defaults
select model_joel.get_table_query(p_table_name => 'CONSOLE_LOGS')
  from dual;

-- with custom settings
select model_joel.get_table_query (
    p_table_name             => 'CONSOLE_LOGS',
    p_max_cols_number        =>  40 ,
    p_max_cols_date          =>  10 ,
    p_max_cols_timestamp_ltz =>  10 ,
    p_max_cols_timestamp_tz  =>  10 ,
    p_max_cols_timestamp     =>  10 ,
    p_max_cols_varchar       =>  80 ,
    p_max_cols_clob          =>  10 );
```

**/

--------------------------------------------------------------------------------

procedure set_session_state (
    p_table_name             in varchar2              ,
    p_owner                  in varchar2 default sys_context('USERENV', 'CURRENT_USER') ,
    p_max_cols_number        in integer  default   20 ,
    p_max_cols_date          in integer  default    5 ,
    p_max_cols_timestamp_ltz in integer  default    5 ,
    p_max_cols_timestamp_tz  in integer  default    5 ,
    p_max_cols_timestamp     in integer  default    5 ,
    p_max_cols_varchar       in integer  default   20 ,
    p_max_cols_clob          in integer  default    5 ,
    p_item_column_names      in varchar2 default null ,
    p_item_messages          in varchar2 default null );
/**

set the session state of application items for a given table. The state is then
used for conditional display of report columns as well for the report headers.

EXAMPLE

```sql
-- with defaults
model_joel.set_session_state(p_table_name => 'CONSOLE_LOGS');

-- with custom settings
model_joel.set_session_state (
    p_table_name             => 'CONSOLE_LOGS' ,
    p_max_cols_number        =>  40 ,
    p_max_cols_date          =>  10 ,
    p_max_cols_timestamp_ltz =>  10 ,
    p_max_cols_timestamp_tz  =>  10 ,
    p_max_cols_timestamp     =>  10 ,
    p_max_cols_varchar       =>  80 ,
    p_max_cols_clob          =>  10 );
```

**/

--------------------------------------------------------------------------------

procedure create_application_items (
    p_app_id                 in integer            ,
    p_max_cols_number        in integer default 20 ,
    p_max_cols_date          in integer default  5 ,
    p_max_cols_timestamp_ltz in integer default  5 ,
    p_max_cols_timestamp_tz  in integer default  5 ,
    p_max_cols_timestamp     in integer default  5 ,
    p_max_cols_varchar       in integer default 20 ,
    p_max_cols_clob          in integer default  5 );
/**

Create application items for a generic report to control which columns to
show and what the headers are.

This procedure needs an APEX session to work and the application needs to be
runtime modifiable. This can be set under: Shared Components > Security
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
        p_app_id                 => 100 ,
        p_max_cols_number        =>  40 ,
        p_max_cols_date          =>  10 ,
        p_max_cols_timestamp_ltz =>  10 ,
        p_max_cols_timestamp_tz  =>  10 ,
        p_max_cols_timestamp     =>  10 ,
        p_max_cols_varchar       =>  80 ,
        p_max_cols_clob          =>  10 );

    commit; --SEC:OK
end;
{{/}}
```

**/

--------------------------------------------------------------------------------

procedure create_interactive_report (
    p_app_id                 in integer            ,
    p_page_id                in integer            ,
    p_region_name            in varchar2           ,
    p_max_cols_number        in integer default 20 ,
    p_max_cols_date          in integer default  5 ,
    p_max_cols_timestamp_ltz in integer default  5 ,
    p_max_cols_timestamp_tz  in integer default  5 ,
    p_max_cols_timestamp     in integer default  5 ,
    p_max_cols_varchar       in integer default 20 ,
    p_max_cols_clob          in integer default  5 );
/**

Create an interactive report with generic columns to show the data of any
table.

This procedure needs an APEX session to work and the application needs to be
runtime modifiable. This cn be set under: Shared Components > Security
Attributes > Runtime API Usage > Check "Modify This Application".

EXAMPLE

```sql
-- in a script with defaults
exec apex_session.create_session(100, 1, 'MY_USER');
exec model_joel.create_interactive_report(100, 1);

-- with custom settings
begin
    apex_session.create_session (
        p_app_id   => 100,
        p_page_id  => 1,
        p_username => 'MY_USER' );

    model_joel.create_interactive_report (
        p_app_id                 => 100 ,
        p_page_id                =>   1 ,
        p_region_name            => 'Data',
        p_max_cols_number        =>  40 ,
        p_max_cols_date          =>  10 ,
        p_max_cols_timestamp_ltz =>  10 ,
        p_max_cols_timestamp_tz  =>  10 ,
        p_max_cols_timestamp     =>  10 ,
        p_max_cols_varchar       =>  80 ,
        p_max_cols_clob          =>  10 );

    commit; --SEC:OK
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

c_N     constant varchar2(1) := 'N';
c_D     constant varchar2(1) := 'D';
c_TSLTZ constant varchar2(5) := 'TSLTZ';
c_TSTZ  constant varchar2(4) := 'TSTZ';
c_TS    constant varchar2(2) := 'TS';
c_VC    constant varchar2(2) := 'VC';
c_CLOB  constant varchar2(5) := 'CLOB';

--------------------------------------------------------------------------------

type columns_row is record (
    data_type                     varchar2(128) ,
    data_type_alias               varchar2(  5) ,
    column_name                   varchar2(128) ,
    column_header                 varchar2(128) ,
    column_alias                  varchar2( 30) ,
    column_expression             varchar2(200) ,
    is_unsupported_data_type      boolean       ,
    is_unavailable_generic_column boolean       );

type columns_tab is table of columns_row index by binary_integer;

g_table_exists boolean;

--------------------------------------------------------------------------------

function get_data_type_alias (
    p_data_type in varchar2 )
    return varchar2
is
begin
    return
        case
            when p_data_type in ('NUMBER', 'FLOAT')                 then c_N
            when p_data_type = 'DATE'                               then c_D
            when p_data_type like 'TIMESTAMP% WITH LOCAL TIME ZONE' then c_TSLTZ
            when p_data_type like 'TIMESTAMP% WITH TIME ZONE'       then c_TSTZ
            when p_data_type like 'TIMESTAMP%'                      then c_TS
            when p_data_type in ('CHAR', 'VARCHAR2', 'RAW')         then c_VC
            when p_data_type = 'CLOB'                               then c_CLOB
            else null
        end;
end get_data_type_alias;

--------------------------------------------------------------------------------

function get_column_alias (
    p_data_type_alias in varchar2 ,
    p_count           in integer  )
    return varchar2
is
begin
    return
        case when p_data_type_alias is not null then
            p_data_type_alias || lpad(to_char(p_count), 3, '0') end;
end get_column_alias;

--------------------------------------------------------------------------------

function get_columns (
    p_table_name             in varchar2              ,
    p_owner                  in varchar2 default sys_context('USERENV', 'CURRENT_USER') ,
    p_max_cols_number        in integer  default   20 ,
    p_max_cols_date          in integer  default    5 ,
    p_max_cols_timestamp_ltz in integer  default    5 ,
    p_max_cols_timestamp_tz  in integer  default    5 ,
    p_max_cols_timestamp     in integer  default    5 ,
    p_max_cols_varchar       in integer  default   20 ,
    p_max_cols_clob          in integer  default    5 )
    return columns_tab
is
    v_column_included   boolean;
    v_columns           columns_tab;
    v_index             pls_integer;
    v_column_alias      varchar2( 30);
    v_column_expression varchar2(200);
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
    begin
        for i in (
            select
                column_name,
                data_type
            from
                all_tab_columns_mv
            where
                owner          = p_owner
                and table_name = p_table_name
            order by
                column_id )
        loop
            g_table_exists    := true;
            v_index           := v_columns.count + 1;

            v_columns(v_index).data_type                     := i.data_type;
            v_columns(v_index).data_type_alias               := get_data_type_alias(i.data_type);
            v_columns(v_index).column_name                   := i.column_name;
            v_columns(v_index).column_header                 := initcap(replace(i.column_name, '_', ' '));
            v_columns(v_index).is_unsupported_data_type      := false;
            v_columns(v_index).is_unavailable_generic_column := false;

            case v_columns(v_index).data_type_alias
                when c_N then
                    v_count_n                            := v_count_n + 1;
                    v_columns(v_index).column_alias      := get_column_alias(v_columns(v_index).data_type_alias, v_count_n);
                    v_columns(v_index).column_expression := i.column_name;
                    if v_count_n > p_max_cols_number then
                        v_columns(v_index).is_unavailable_generic_column := true;
                    end if;

                when c_D then
                    v_count_d                            := v_count_d + 1;
                    v_columns(v_index).column_alias      := get_column_alias(v_columns(v_index).data_type_alias, v_count_d);
                    v_columns(v_index).column_expression := i.column_name;
                    if v_count_d > p_max_cols_date then
                        v_columns(v_index).is_unavailable_generic_column := true;
                    end if;

                when c_TSLTZ then
                    v_count_tsltz                        := v_count_tsltz + 1;
                    v_columns(v_index).column_alias      := get_column_alias(v_columns(v_index).data_type_alias, v_count_tsltz);
                    v_columns(v_index).column_expression := i.column_name;
                    if v_count_tsltz > p_max_cols_timestamp_ltz then
                        v_columns(v_index).is_unavailable_generic_column := true;
                    end if;

                when c_TSTZ then
                    v_count_tstz                         := v_count_tstz + 1;
                    v_columns(v_index).column_alias      := get_column_alias(v_columns(v_index).data_type_alias, v_count_tstz);
                    v_columns(v_index).column_expression := i.column_name;
                    if v_count_tstz > p_max_cols_timestamp_tz then
                        v_columns(v_index).is_unavailable_generic_column := true;
                    end if;

                when c_TS then
                    v_count_ts                           := v_count_ts + 1;
                    v_columns(v_index).column_alias      := get_column_alias(v_columns(v_index).data_type_alias, v_count_ts);
                    v_columns(v_index).column_expression := i.column_name;
                    if v_count_ts > p_max_cols_timestamp then
                        v_columns(v_index).is_unavailable_generic_column := true;
                    end if;

                when c_VC then
                    v_count_vc                           := v_count_vc + 1;
                    v_columns(v_index).column_alias      := get_column_alias(v_columns(v_index).data_type_alias, v_count_vc);
                    v_columns(v_index).column_expression := i.column_name;
                    if v_count_vc > p_max_cols_varchar then
                        v_columns(v_index).is_unavailable_generic_column := true;
                    end if;

                when c_CLOB then
                    v_count_clob                         := v_count_clob + 1;
                    v_columns(v_index).column_alias      := get_column_alias(v_columns(v_index).data_type_alias, v_count_clob);
                    v_columns(v_index).column_expression := 'substr(' || i.column_name || ', 1, 4000)';
                    if v_count_clob > p_max_cols_clob then
                        v_columns(v_index).is_unavailable_generic_column := true;
                    end if;

                else
                    v_columns(v_index).is_unsupported_data_type := true;
            end case;

        end loop;
    end process_table_columns;

    ----------------------------------------

    procedure fill_gaps (
        p_data_type_alias in varchar2 )
    is
        v_count      pls_integer;
        v_max_cols   pls_integer;
        v_expression varchar2(200);
    begin
        v_count :=
            case p_data_type_alias
                when c_N     then v_count_n
                when c_D     then v_count_d
                when c_TSLTZ then v_count_tsltz
                when c_TSTZ  then v_count_tstz
                when c_TS    then v_count_ts
                when c_VC    then v_count_vc
                when c_CLOB  then v_count_clob
            end + 1;

        v_max_cols :=
            case p_data_type_alias
                when c_N     then p_max_cols_number
                when c_D     then p_max_cols_date
                when c_TSLTZ then p_max_cols_timestamp_ltz
                when c_TSTZ  then p_max_cols_timestamp_tz
                when c_TS    then p_max_cols_timestamp
                when c_VC    then p_max_cols_varchar
                when c_CLOB  then p_max_cols_clob
            end;

        v_expression :=
            case p_data_type_alias
                when c_N     then 'cast(null as number)'
                when c_D     then 'cast(null as date)'
                when c_TSLTZ then 'cast(null as timestamp with local time zone)'
                when c_TSTZ  then 'cast(null as timestamp with time zone)'
                when c_TS    then 'cast(null as timestamp)'
                when c_VC    then 'cast(null as varchar2(4000))'
                when c_CLOB  then 'to_clob(null)'
            end;

        for i in v_count .. v_max_cols
        loop
            v_index := v_columns.count + 1;

            v_columns(v_index).column_alias                  := get_column_alias(p_data_type_alias, i);
            v_columns(v_index).column_expression             := v_expression;
            v_columns(v_index).is_unsupported_data_type      := false;
            v_columns(v_index).is_unavailable_generic_column := false;
        end loop;
    end fill_gaps;

    ----------------------------------------

begin
    g_table_exists := false;

    process_table_columns;

    fill_gaps ( c_N     );
    fill_gaps ( c_D     );
    fill_gaps ( c_TSLTZ );
    fill_gaps ( c_TSTZ  );
    fill_gaps ( c_TS    );
    fill_gaps ( c_VC    );
    fill_gaps ( c_CLOB  );

    return v_columns;

end get_columns;

--------------------------------------------------------------------------------

function get_table_query (
    p_table_name             in varchar2              ,
    p_owner                  in varchar2 default sys_context('USERENV', 'CURRENT_USER') ,
    p_max_cols_number        in integer  default   20 ,
    p_max_cols_date          in integer  default    5 ,
    p_max_cols_timestamp_ltz in integer  default    5 ,
    p_max_cols_timestamp_tz  in integer  default    5 ,
    p_max_cols_timestamp     in integer  default    5 ,
    p_max_cols_varchar       in integer  default   20 ,
    p_max_cols_clob          in integer  default    5 )
    return clob
is
    v_return        clob;
    v_columns       columns_tab;
    v_sep           varchar2(2) := ',' || chr(10);
    v_column_indent varchar2(7) := '       ';
begin
    v_columns := get_columns (
        p_table_name             => p_table_name             ,
        p_max_cols_number        => p_max_cols_number        ,
        p_max_cols_date          => p_max_cols_date          ,
        p_max_cols_timestamp_ltz => p_max_cols_timestamp_ltz ,
        p_max_cols_timestamp_tz  => p_max_cols_timestamp_tz  ,
        p_max_cols_timestamp     => p_max_cols_timestamp     ,
        p_max_cols_varchar       => p_max_cols_varchar       ,
        p_max_cols_clob          => p_max_cols_clob          );

    for i in 1 .. v_columns.count loop
        if v_columns(i).column_alias is not null then
            v_return := v_return
                || v_column_indent
                || v_columns(i).column_expression
                || ' as '
                || v_columns(i).column_alias
                || v_sep;
        end if;
    end loop;

    v_return := 'select ' || rtrim( ltrim(v_return), v_sep ) || chr(10) ||
                '  from ' || case when g_table_exists
                                  then p_table_name
                                  else 'dual'|| chr(10) || ' where 1 = 2'
                             end;

    return v_return;
end get_table_query;

--------------------------------------------------------------------------------

procedure set_session_state (
    p_table_name             in varchar2              ,
    p_owner                  in varchar2 default sys_context('USERENV', 'CURRENT_USER') ,
    p_max_cols_number        in integer  default   20 ,
    p_max_cols_date          in integer  default    5 ,
    p_max_cols_timestamp_ltz in integer  default    5 ,
    p_max_cols_timestamp_tz  in integer  default    5 ,
    p_max_cols_timestamp     in integer  default    5 ,
    p_max_cols_varchar       in integer  default   20 ,
    p_max_cols_clob          in integer  default    5 ,
    p_item_column_names      in varchar2 default null ,
    p_item_messages          in varchar2 default null )
is
    v_columns_tab                columns_tab;
    v_columns_csv                varchar2(32767);
    v_unsupported_data_types     varchar2(32767);
    v_unavailable_generic_column varchar2(32767);
begin
    v_columns_tab := get_columns (
        p_table_name             => p_table_name             ,
        p_owner                  => p_owner                  ,
        p_max_cols_number        => p_max_cols_number        ,
        p_max_cols_date          => p_max_cols_date          ,
        p_max_cols_timestamp_ltz => p_max_cols_timestamp_ltz ,
        p_max_cols_timestamp_tz  => p_max_cols_timestamp_tz  ,
        p_max_cols_timestamp     => p_max_cols_timestamp     ,
        p_max_cols_varchar       => p_max_cols_varchar       ,
        p_max_cols_clob          => p_max_cols_clob          );

    for i in 1 .. v_columns_tab.count loop
        if      not v_columns_tab(i).is_unsupported_data_type
            and not v_columns_tab(i).is_unavailable_generic_column
        then
            apex_util.set_session_state (
                p_name  => v_columns_tab(i).column_alias,
                p_value => v_columns_tab(i).column_header);
            v_columns_csv := v_columns_csv || v_columns_tab(i).column_alias || ',';
        end if;

        if v_columns_tab(i).is_unsupported_data_type then
            v_unsupported_data_types := v_unsupported_data_types ||
                v_columns_tab(i).column_header ||
                ' (' || lower(v_columns_tab(i).data_type) || '), ';
        end if;

        if v_columns_tab(i).is_unavailable_generic_column then
            v_unavailable_generic_column := v_unavailable_generic_column ||
                v_columns_tab(i).column_header ||
                ' (' || lower(v_columns_tab(i).data_type) || '), ';
        end if;
    end loop;

    if p_item_column_names is not null then
        apex_util.set_session_state (
            p_name  => p_item_column_names,
            p_value => rtrim(v_columns_csv, ',') );
    end if;

    if p_item_messages is not null then
        if v_unsupported_data_types is not null then
            v_unsupported_data_types := 'Skipped columns because of unsupported data types: ' ||
                                        rtrim(v_unsupported_data_types, ', ') || '. ';
        end if;

        if v_unavailable_generic_column is not null then
            v_unavailable_generic_column := 'Skipped columns because of unavailable generic columns: ' ||
                                        rtrim(v_unavailable_generic_column, ', ') || '.';
        end if;

        apex_util.set_session_state (
            p_name  => p_item_messages,
            p_value => substr(v_unsupported_data_types || v_unavailable_generic_column, 1, 32767 ) );
    end if;
end set_session_state;

--------------------------------------------------------------------------------

procedure create_application_items (
    p_app_id                 in integer            ,
    p_max_cols_number        in integer default 20 ,
    p_max_cols_date          in integer default  5 ,
    p_max_cols_timestamp_ltz in integer default  5 ,
    p_max_cols_timestamp_tz  in integer default  5 ,
    p_max_cols_timestamp     in integer default  5 ,
    p_max_cols_varchar       in integer default 20 ,
    p_max_cols_clob          in integer default  5 )
is
    v_app_items wwv_flow_global.vc_map;

    ----------------------------------------

    procedure create_items (
        p_data_type_alias in varchar2 )
    is
        v_column_alias   varchar2(30);
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
            case p_data_type_alias
                when c_N     then p_max_cols_number
                when c_D     then p_max_cols_date
                when c_TSLTZ then p_max_cols_timestamp_ltz
                when c_TSTZ  then p_max_cols_timestamp_tz
                when c_TS    then p_max_cols_timestamp
                when c_VC    then p_max_cols_varchar
                when c_CLOB  then p_max_cols_clob
            end;

        for i in 1 .. v_max_cols
        loop
            v_column_alias := get_column_alias(p_data_type_alias, i);

            if not v_app_items.exists(v_column_alias) then
                wwv_flow_imp_shared.create_flow_item (
                    p_flow_id          => p_app_id,
                    p_id               => wwv_flow_id.next_val,
                    p_name             => v_column_alias,
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
    create_items( c_N     );
    create_items( c_D     );
    create_items( c_TSLTZ );
    create_items( c_TSTZ  );
    create_items( c_TS    );
    create_items( c_VC    );
    create_items( c_CLOB  );

end create_application_items;

--------------------------------------------------------------------------------

procedure create_interactive_report (
    p_app_id                 in integer             ,
    p_page_id                in integer             ,
    p_region_name            in varchar2            ,
    p_max_cols_number        in integer  default 20 ,
    p_max_cols_date          in integer  default  5 ,
    p_max_cols_timestamp_ltz in integer  default  5 ,
    p_max_cols_timestamp_tz  in integer  default  5 ,
    p_max_cols_timestamp     in integer  default  5 ,
    p_max_cols_varchar       in integer  default 20 ,
    p_max_cols_clob          in integer  default  5 )
is
    v_display_order number := 10;
    v_count         number;

    ----------------------------------------

    function get_template_id (
        p_type  in varchar2,
        p_name  in varchar2,
        p_theme in number default 42)
        return number
    is
        v_return number;
    begin
        select
            template_id
        into
            v_return
        from
            apex_application_templates
        where
            application_id    = p_app_id
            and theme_number  = p_theme
            and template_type = p_type
            and template_name = p_name;
    return v_return;
    exception
        when no_data_found then
            return null;
    end get_template_id;

    ----------------------------------------

    function report_exists return boolean is
    begin
        select
            count(*)
        into
            v_count
        from
            apex_application_page_regions
        where
            application_id  = p_app_id
            and page_id     = p_page_id
            and region_name = p_region_name;

        return case when v_count > 0 then true else false end;
    end report_exists;

    procedure create_report
    is
        v_temp_id number;
    begin
        wwv_flow_imp_page.create_page_plug (
            p_flow_id                     => p_app_id,
            p_page_id                     => p_page_id,
            p_id                          => wwv_flow_id.next_val,
            p_plug_name                   => p_region_name,
            p_region_template_options     => '#DEFAULT#',
            p_component_template_options  => '#DEFAULT#',
            p_plug_template               => get_template_id('Region', 'Interactive Report'),
            p_plug_display_sequence       => 10,
            p_include_in_reg_disp_sel_yn  => 'Y',
            p_query_type                  => 'FUNC_BODY_RETURNING_SQL',
            p_function_body_language      => 'PLSQL',
            p_plug_source                 => 'return model_joel.get_table_query(:p'||p_page_id||'_fixme)',
            p_plug_source_type            => 'NATIVE_IR',
            p_plug_query_options          => 'DERIVED_REPORT_COLUMNS',
            p_plug_column_width           => 'style="overflow:auto;"',
            p_prn_content_disposition     => 'ATTACHMENT',
            p_prn_units                   => 'INCHES',
            p_prn_paper_size              => 'LETTER',
            p_prn_width                   => 11,
            p_prn_height                  => 8.5,
            p_prn_orientation             => 'HORIZONTAL',
            p_prn_page_header             => 'Generic Table Data Report',
            p_prn_page_header_font_color  => '#000000',
            p_prn_page_header_font_family => 'Helvetica',
            p_prn_page_header_font_weight => 'normal',
            p_prn_page_header_font_size   => '12',
            p_prn_page_footer_font_color  => '#000000',
            p_prn_page_footer_font_family => 'Helvetica',
            p_prn_page_footer_font_weight => 'normal',
            p_prn_page_footer_font_size   => '12',
            p_prn_header_bg_color         => '#EEEEEE',
            p_prn_header_font_color       => '#000000',
            p_prn_header_font_family      => 'Helvetica',
            p_prn_header_font_weight      => 'bold',
            p_prn_header_font_size        => '10',
            p_prn_body_bg_color           => '#FFFFFF',
            p_prn_body_font_color         => '#000000',
            p_prn_body_font_family        => 'Helvetica',
            p_prn_body_font_weight        => 'normal',
            p_prn_body_font_size          => '10',
            p_prn_border_width            => .5,
            p_prn_page_header_alignment   => 'CENTER',
            p_prn_page_footer_alignment   => 'CENTER',
            p_prn_border_color            => '#666666' );

        v_temp_id := wwv_flow_id.next_val;

        wwv_flow_imp_page.create_worksheet (
            p_flow_id                => p_app_id,
            p_page_id                => p_page_id,
            p_id                     => v_temp_id,
            p_max_row_count          => '1000000',
            p_no_data_found_message  => 'No data found.',
            p_max_rows_per_page      => '1000',
            p_allow_report_saving    => 'N',
            p_pagination_type        => 'ROWS_X_TO_Y',
            p_pagination_display_pos => 'TOP_AND_BOTTOM_LEFT',
            p_show_display_row_count => 'Y',
            p_report_list_mode       => 'TABS',
            p_lazy_loading           => false,
            p_show_reset             => 'N',
            p_download_formats       => 'CSV:HTML:XLSX:PDF',
            p_enable_mail_download   => 'Y',
            p_detail_link_text       => '<img src="#IMAGE_PREFIX#app_ui/img/icons/apex-edit-view.png" class="apex-edit-view" alt="">',
            p_owner                  => apex_application.g_user,
            p_internal_uid           => v_temp_id );
    end create_report;

    ----------------------------------------

    procedure create_report_columns (
        p_data_type_alias in varchar2 )
    is
        v_column_alias     varchar2(30);
        v_column_type      varchar2(30);
        v_column_alignment varchar2(30);
        v_format_mask      varchar2(30);
        v_tz_dependent     varchar2( 1);
        v_max_cols         pls_integer;
        v_count_n          pls_integer := 0;
        v_count_d          pls_integer := 0;
        v_count_ts         pls_integer := 0;
        v_count_tstz       pls_integer := 0;
        v_count_tsltz      pls_integer := 0;
        v_count_vc         pls_integer := 0;
        v_count_clob       pls_integer := 0;
    begin
        v_max_cols :=
            case p_data_type_alias
                when c_N     then p_max_cols_number
                when c_D     then p_max_cols_date
                when c_TSLTZ then p_max_cols_timestamp_ltz
                when c_TSTZ  then p_max_cols_timestamp_tz
                when c_TS    then p_max_cols_timestamp
                when c_VC    then p_max_cols_varchar
                when c_CLOB  then p_max_cols_clob
            end;

        v_column_type :=
            case p_data_type_alias
                when c_N     then 'NUMBER'
                when c_D     then 'DATE'
                when c_TSLTZ then 'DATE'
                when c_TSTZ  then 'DATE'
                when c_TS    then 'DATE'
                when c_VC    then 'STRING'
                when c_CLOB  then 'CLOB'
            end;

        v_column_alignment :=
            case p_data_type_alias
                when c_N     then 'RIGHT'
                when c_D     then 'CENTER'
                when c_TSLTZ then 'CENTER'
                when c_TSTZ  then 'CENTER'
                when c_TS    then 'CENTER'
                when c_VC    then 'LEFT'
                when c_CLOB  then 'LEFT'
            end;

        v_format_mask :=
            case p_data_type_alias
                when c_D     then 'YYYY-MM-DD HH24:MI:SS'
                when c_TSLTZ then 'YYYY-MM-DD HH24:MI:SSXFF TZR'
                when c_TSTZ  then 'YYYY-MM-DD HH24:MI:SSXFF TZR'
                when c_TS    then 'YYYY-MM-DD HH24:MI:SSXFF'
                else              null
            end;

        v_tz_dependent :=
            case p_data_type_alias
                when c_TSLTZ then 'Y'
                else              'N'
            end;

        for i in 1 .. v_max_cols
        loop
            v_column_alias := get_column_alias(p_data_type_alias, i);

            wwv_flow_imp_page.create_worksheet_column (
                p_id                     => wwv_flow_id.next_val,
                p_db_column_name         => v_column_alias,
                p_display_order          => v_display_order,
                p_column_identifier      => v_column_alias,
                p_column_label           => '&'||v_column_alias||'.',
                p_column_type            => v_column_type,
                p_column_alignment       => v_column_alignment,
                p_format_mask            => v_format_mask,
                p_tz_dependent           => v_tz_dependent,
                p_display_condition_type => 'ITEM_IS_NOT_NULL',
                p_display_condition      => v_column_alias,
                p_use_as_row_header      => 'N',
                --disable some things for CLOBs
                p_allow_sorting          => case when v_column_type = c_CLOB then 'N' else 'Y' end,
                p_allow_ctrl_breaks      => case when v_column_type = c_CLOB then 'N' else 'Y' end,
                p_allow_aggregations     => case when v_column_type = c_CLOB then 'N' else 'Y' end,
                p_allow_computations     => case when v_column_type = c_CLOB then 'N' else 'Y' end,
                p_allow_charting         => case when v_column_type = c_CLOB then 'N' else 'Y' end,
                p_allow_group_by         => case when v_column_type = c_CLOB then 'N' else 'Y' end,
                p_allow_pivot            => case when v_column_type = c_CLOB then 'N' else 'Y' end,
                p_rpt_show_filter_lov    => case when v_column_type = c_CLOB then 'N' else 'D' end );

            v_display_order := v_display_order + 10;
        end loop;
    end create_report_columns;

    ----------------------------------------

begin

    if not report_exists then
        create_report;
        create_report_columns ( c_N     );
        create_report_columns ( c_D     );
        create_report_columns ( c_TSLTZ );
        create_report_columns ( c_TSTZ  );
        create_report_columns ( c_TS    );
        create_report_columns ( c_VC    );
        create_report_columns ( c_CLOB  );
    end if;

end create_interactive_report;

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

--exec apex_session.create_session(103, 1, 'OGOBRECH');
--exec model_joel.create_application_items(103);
--exec model_joel.create_interactive_report(103,1,'Test Report 8');

