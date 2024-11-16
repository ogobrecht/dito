prompt ORACLE DATA MODEL UTILITIES - APEX EXTENSION PACKAGE

set define on
set serveroutput on
set verify off
set feedback off
set linesize 240
set trimout on
set trimspool on
whenever sqlerror exit sql.sqlcode rollback

prompt - Create or refresh needed mviews (this can take a minute or so...)
begin
    if model.all_base_mviews_exist then
        dbms_output.put_line('- Mviews already existing - nothing to do');
    else
        model.create_or_refresh_base_mviews;
    end if;
end;
/

prompt - Set compiler flags
declare
    l_apex_installed     varchar2(5) := 'FALSE'; -- Do not change (is set dynamically).
    l_utils_public       varchar2(5) := 'FALSE'; -- Make utilities public available (for testing or other usages).
    l_native_compilation boolean     := false;   -- Set this to true at your own risk (in the Oracle cloud you will get likely an "insufficient privileges" error)
    l_count pls_integer;
begin

    execute immediate 'alter session set plsql_warnings = ''enable:all,disable:5004,disable:6005,disable:6006,disable:6009,disable:6010,disable:6027,disable:7207''';
    execute immediate 'alter session set plscope_settings = ''identifiers:all''';
    execute immediate 'alter session set plsql_optimize_level = 3';

    if l_native_compilation then
        execute immediate 'alter session set plsql_code_type=''native''';
    end if;

    select count(*) into l_count from all_objects where object_type = 'SYNONYM' and object_name = 'APEX_EXPORT';
    l_apex_installed := case when l_count = 0 then 'FALSE' else 'TRUE' end;

    execute immediate 'alter session set plsql_ccflags = '''
        || 'APEX_INSTALLED:' || l_apex_installed || ','
        || 'UTILS_PUBLIC:'   || l_utils_public   || '''';

    -- select * from all_plsql_object_settings where name = 'MODEL';
end;
/


prompt - Package model_joel (spec)
create or replace package model_joel authid current_user is

/**

Oracle Data Model Utilities - APEX Extension
============================================

Oracle APEX helpers to support a generic Interactive Report to show the data
of any table.

**/

TYPE t_indexes_row IS RECORD (
    table_name           varchar2( 128) ,
    needed_index_columns varchar2(4000) ,
    index_name           varchar2( 128) ,
    ddl                  varchar2(4000) );

TYPE t_indexes_tab IS TABLE OF t_indexes_row;

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
    p_item_messages          in varchar2 default null ,
    p_item_type              in varchar2 default null );
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
runtime modifiable. This can be set under: Shared Components > Security
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

    commit;
end;
{{/}}
```

**/

--------------------------------------------------------------------------------

function get_overview_counts (
    p_owner           in varchar2 default sys_context('USERENV', 'CURRENT_USER') ,
    p_objects_include in varchar2 default null ,
    p_objects_exclude in varchar2 default null ,
    p_columns_include in varchar2 default null )
    return varchar2;
/**

Get the number of tables, views and columns for a schema. Returns JSON as
varchar2.

p_objects_include and p_objects_exclude are case insensitive contains
filters. Multiple terms can be given separated by spaces.

EXAMPLE

```sql
select model_joel.get_overview_counts (
           p_owner           => 'MDSYS',
           p_objects_include => 'coord meta' )
       as overview_counts
  from dual;
```

**/

--------------------------------------------------------------------------------

function get_detail_counts (
    p_owner                in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
    p_object_name          in varchar2              ,
    p_model_exclude_tables in varchar2 default null )
    return varchar2;
/**

Get the number of rows, columns, constraints, indexes, triggers and
dependecies for a table or view. Returns JSON as varchar2.

p_model_exclude_tables is a case insensitive contains filter. Multiple terms
can be given separated by spaces.

EXAMPLE

```sql
select model_joel.get_detail_counts (
           p_owner       => 'MDSYS',
           p_object_name => 'SDO_COORD_OP_PARAM_VALS' )
       as details_counts
  from dual;
```

**/

--------------------------------------------------------------------------------

function get_object_meta (
    p_owner       in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
    p_object_name in varchar2 ,
    p_object_type in varchar2 default null)
    return clob;
/**

Get additional meta data for objects in HTML text format, which are not
already listed by the dictionary views user_tab_columns user_constraints,
user_indexes, user_triggers and user_dependencies.

EXAMPLE

```sql
select model_joel.get_object_meta (
           p_owner       => 'MDSYS',
           p_object_name => 'SDO_COORD_OP_PARAM_VALS' )
       as overview_counts
  from dual;
```

**/

--------------------------------------------------------------------------------

function get_bg_execution_status (
    p_execution_id in number )
    return varchar2;
/**

Get the current status of the background execution for the given id. Returns
JSON as varchar2.

EXAMPLE

```sql
select model_joel.get_bg_execution_status (
           p_execution_id => 12345 )
       as overview_counts
  from dual;
```

**/

--------------------------------------------------------------------------------

function view_missing_fk_indexes (
    p_owner varchar2 default sys_context('USERENV', 'CURRENT_USER') )
return t_indexes_tab pipelined;
/**

Table function which lists the missing foreign key indexes for the given
schema/owner.

EXAMPLE

```sql
select * from table (model_joel.view_missing_fk_indexes);
```

**/

--------------------------------------------------------------------------------

procedure create_missing_fk_indexes;

/**

A convenience procedure which creates missing foreign key indexes and refreshes
 the 11 base materialized views .

EXAMPLES

```sql
set serveroutput on
exec model_joel.create_missing_fk_indexes;
```

**/

--------------------------------------------------------------------------------

procedure create_or_refresh_base_mviews (
    p_totalwork integer default null,
    p_sofar     integer default null );

/**

A convenience procedure which creates or refreshes the base materialized
views defined in model.g_base_mviews with updating APEX background execution
status.

The parameters p_totalwork and p_sofar can be used to overwrite the calculated
work, when the procedure is called as a subprocedure in a greater context.

EXAMPLES

```sql
set serveroutput on
exec model_joel.create_or_refresh_base_mviews;
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

type skipped_tab is table of pls_integer index by varchar2(30);

g_skipped_unsupported skipped_tab;
g_skipped_unavailable skipped_tab;
g_table_exists boolean;

--------------------------------------------------------------------------------

procedure count_skipped_unsupported (
    p_data_type varchar2 )
is
    l_datatype varchar2(30) := lower(p_data_type);
begin
    if g_skipped_unsupported.exists(l_datatype) then
        g_skipped_unsupported(l_datatype) := g_skipped_unsupported(l_datatype) + 1;
    else
        g_skipped_unsupported(l_datatype) := 1;
    end if;
end count_skipped_unsupported;

--------------------------------------------------------------------------------

procedure count_skipped_unavailable (
    p_data_type varchar2 )
is
    l_datatype varchar2(30) := lower(p_data_type);
begin
    if g_skipped_unavailable.exists(l_datatype) then
        g_skipped_unavailable(l_datatype) := g_skipped_unavailable(l_datatype) + 1;
    else
        g_skipped_unavailable(l_datatype) := 1;
    end if;
end count_skipped_unavailable;

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
    l_column_included   boolean;
    l_columns           columns_tab;
    l_index             pls_integer;
    l_column_alias      varchar2( 30);
    l_column_expression varchar2(200);
    l_count_n           pls_integer := 0;
    l_count_vc          pls_integer := 0;
    l_count_clob        pls_integer := 0;
    l_count_d           pls_integer := 0;
    l_count_ts          pls_integer := 0;
    l_count_tstz        pls_integer := 0;
    l_count_tsltz       pls_integer := 0;

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
            l_index           := l_columns.count + 1;

            l_columns(l_index).data_type                     := i.data_type;
            l_columns(l_index).data_type_alias               := get_data_type_alias(i.data_type);
            l_columns(l_index).column_name                   := i.column_name;
            l_columns(l_index).column_header                 := initcap(replace(i.column_name, '_', ' '));
            l_columns(l_index).is_unsupported_data_type      := false;
            l_columns(l_index).is_unavailable_generic_column := false;

            case l_columns(l_index).data_type_alias
                when c_N then
                    l_count_n                            := l_count_n + 1;
                    l_columns(l_index).column_alias      := get_column_alias(l_columns(l_index).data_type_alias, l_count_n);
                    l_columns(l_index).column_expression := '"' || i.column_name || '"';
                    if l_count_n > p_max_cols_number then
                        l_columns(l_index).is_unavailable_generic_column := true;
                    end if;

                when c_D then
                    l_count_d                            := l_count_d + 1;
                    l_columns(l_index).column_alias      := get_column_alias(l_columns(l_index).data_type_alias, l_count_d);
                    l_columns(l_index).column_expression := '"' || i.column_name || '"';
                    if l_count_d > p_max_cols_date then
                        l_columns(l_index).is_unavailable_generic_column := true;
                    end if;

                when c_TSLTZ then
                    l_count_tsltz                        := l_count_tsltz + 1;
                    l_columns(l_index).column_alias      := get_column_alias(l_columns(l_index).data_type_alias, l_count_tsltz);
                    l_columns(l_index).column_expression := '"' || i.column_name || '"';
                    if l_count_tsltz > p_max_cols_timestamp_ltz then
                        l_columns(l_index).is_unavailable_generic_column := true;
                    end if;

                when c_TSTZ then
                    l_count_tstz                         := l_count_tstz + 1;
                    l_columns(l_index).column_alias      := get_column_alias(l_columns(l_index).data_type_alias, l_count_tstz);
                    l_columns(l_index).column_expression := '"' || i.column_name || '"';
                    if l_count_tstz > p_max_cols_timestamp_tz then
                        l_columns(l_index).is_unavailable_generic_column := true;
                    end if;

                when c_TS then
                    l_count_ts                           := l_count_ts + 1;
                    l_columns(l_index).column_alias      := get_column_alias(l_columns(l_index).data_type_alias, l_count_ts);
                    l_columns(l_index).column_expression := '"' || i.column_name || '"';
                    if l_count_ts > p_max_cols_timestamp then
                        l_columns(l_index).is_unavailable_generic_column := true;
                    end if;

                when c_VC then
                    l_count_vc                           := l_count_vc + 1;
                    l_columns(l_index).column_alias      := get_column_alias(l_columns(l_index).data_type_alias, l_count_vc);
                    l_columns(l_index).column_expression := '"' || i.column_name || '"';
                    if l_count_vc > p_max_cols_varchar then
                        l_columns(l_index).is_unavailable_generic_column := true;
                    end if;

                when c_CLOB then
                    l_count_clob                         := l_count_clob + 1;
                    l_columns(l_index).column_alias      := get_column_alias(l_columns(l_index).data_type_alias, l_count_clob);
                    l_columns(l_index).column_expression := 'substr("' || i.column_name || '", 1, 4000)';
                    if l_count_clob > p_max_cols_clob then
                        l_columns(l_index).is_unavailable_generic_column := true;
                    end if;

                else
                    l_columns(l_index).is_unsupported_data_type := true;
            end case;

        end loop;
    end process_table_columns;

    ----------------------------------------

    procedure fill_gaps (
        p_data_type_alias in varchar2 )
    is
        l_count      pls_integer;
        l_max_cols   pls_integer;
        l_expression varchar2(200);
    begin
        l_count :=
            case p_data_type_alias
                when c_N     then l_count_n
                when c_D     then l_count_d
                when c_TSLTZ then l_count_tsltz
                when c_TSTZ  then l_count_tstz
                when c_TS    then l_count_ts
                when c_VC    then l_count_vc
                when c_CLOB  then l_count_clob
            end + 1;

        l_max_cols :=
            case p_data_type_alias
                when c_N     then p_max_cols_number
                when c_D     then p_max_cols_date
                when c_TSLTZ then p_max_cols_timestamp_ltz
                when c_TSTZ  then p_max_cols_timestamp_tz
                when c_TS    then p_max_cols_timestamp
                when c_VC    then p_max_cols_varchar
                when c_CLOB  then p_max_cols_clob
            end;

        l_expression :=
            case p_data_type_alias
                when c_N     then 'cast(null as number)'
                when c_D     then 'cast(null as date)'
                when c_TSLTZ then 'cast(null as timestamp with local time zone)'
                when c_TSTZ  then 'cast(null as timestamp with time zone)'
                when c_TS    then 'cast(null as timestamp)'
                when c_VC    then 'cast(null as varchar2(4000))'
                when c_CLOB  then 'to_clob(null)'
            end;

        for i in l_count .. l_max_cols
        loop
            l_index := l_columns.count + 1;

            l_columns(l_index).column_alias                  := get_column_alias(p_data_type_alias, i);
            l_columns(l_index).column_expression             := l_expression;
            l_columns(l_index).is_unsupported_data_type      := false;
            l_columns(l_index).is_unavailable_generic_column := false;
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

    return l_columns;

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
    l_return        clob;
    l_columns       columns_tab;
    l_sep           varchar2(2) := ',' || chr(10);
    l_column_indent varchar2(7) := '       ';
begin
    l_columns := get_columns (
        p_table_name             => p_table_name             ,
        p_owner                  => p_owner                  ,
        p_max_cols_number        => p_max_cols_number        ,
        p_max_cols_date          => p_max_cols_date          ,
        p_max_cols_timestamp_ltz => p_max_cols_timestamp_ltz ,
        p_max_cols_timestamp_tz  => p_max_cols_timestamp_tz  ,
        p_max_cols_timestamp     => p_max_cols_timestamp     ,
        p_max_cols_varchar       => p_max_cols_varchar       ,
        p_max_cols_clob          => p_max_cols_clob          );

    for i in 1 .. l_columns.count loop
        if l_columns(i).column_alias is not null then
            l_return := l_return
                || l_column_indent
                || l_columns(i).column_expression
                || ' as '
                || l_columns(i).column_alias
                || l_sep;
        end if;
    end loop;

    l_return := 'select ' || rtrim( ltrim(l_return), l_sep ) || chr(10) ||
                '  from ' || case when g_table_exists
                                  then p_owner || '.' || p_table_name
                                  else 'sys.dual'|| chr(10) || ' where 1 = 2'
                             end;

    return l_return;
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
    p_item_messages          in varchar2 default null ,
    p_item_type              in varchar2 default null )
is
    l_columns_tab                columns_tab;
    l_columns_csv                varchar2(32767);
    l_unsupported_data_types     varchar2(32767);
    l_unavailable_generic_column varchar2(32767);
    l_type                       varchar2(128);
    l_index                      varchar2(30);
begin
    l_columns_tab := get_columns (
        p_table_name             => p_table_name             ,
        p_owner                  => p_owner                  ,
        p_max_cols_number        => p_max_cols_number        ,
        p_max_cols_date          => p_max_cols_date          ,
        p_max_cols_timestamp_ltz => p_max_cols_timestamp_ltz ,
        p_max_cols_timestamp_tz  => p_max_cols_timestamp_tz  ,
        p_max_cols_timestamp     => p_max_cols_timestamp     ,
        p_max_cols_varchar       => p_max_cols_varchar       ,
        p_max_cols_clob          => p_max_cols_clob          );

    for i in 1 .. l_columns_tab.count loop
        if      not l_columns_tab(i).is_unsupported_data_type
            and not l_columns_tab(i).is_unavailable_generic_column
        then
            apex_util.set_session_state (
                p_name  => l_columns_tab(i).column_alias,
                p_value => l_columns_tab(i).column_header);
            l_columns_csv := l_columns_csv || l_columns_tab(i).column_alias || ',';
        else
            if l_columns_tab(i).is_unsupported_data_type then
                count_skipped_unsupported(l_columns_tab(i).data_type);
            end if;
            if l_columns_tab(i).is_unavailable_generic_column then
                count_skipped_unavailable(l_columns_tab(i).data_type);
            end if;
        end if;
    end loop;

    if p_item_column_names is not null then
        apex_util.set_session_state (
            p_name  => p_item_column_names,
            p_value => rtrim(l_columns_csv, ',') );
    end if;

    if p_item_messages is not null then
        if g_skipped_unsupported.count > 0 then
            l_unsupported_data_types := 'Skipped because of unsupported data types: ';
            l_index := g_skipped_unsupported.first;
            while l_index is not null loop
                l_unsupported_data_types := l_unsupported_data_types ||
                    to_char(g_skipped_unsupported(l_index)) ||
                    ' column' || case when g_skipped_unsupported(l_index) > 1 then 's' end ||
                    ' of data type ' || l_index || ', ';
                l_index := g_skipped_unsupported.next(l_index);
            end loop;
            l_unsupported_data_types := rtrim(l_unsupported_data_types, ', ') || '.';
        end if;

        if g_skipped_unavailable.count > 0 then
            l_unavailable_generic_column := 'Skipped because of unavailable generic columns: ';
            l_index := g_skipped_unavailable.first;
            while l_index is not null loop
                l_unavailable_generic_column := l_unavailable_generic_column ||
                    to_char(g_skipped_unavailable(l_index)) ||
                    ' column' || case when g_skipped_unavailable(l_index) > 1 then 's' end ||
                    ' of data type ' || l_index || ', ';
                l_index := g_skipped_unavailable.next(l_index);
            end loop;
            l_unavailable_generic_column := rtrim(l_unavailable_generic_column, ', ') || '.';
        end if;

        apex_util.set_session_state (
            p_name  => p_item_messages,
            p_value => substr(l_unsupported_data_types || ' ' || l_unavailable_generic_column, 1, 32767 ) );
    end if;

    if p_item_type is not null then
        select nvl(min(object_type), 'UNKNOWN')
          into l_type
          from all_objects_mv
         where owner       = p_owner
           and object_name = p_table_name;

        apex_util.set_session_state (
            p_name  => p_item_type,
            p_value => l_type );
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
    l_app_items wwv_flow_global.vc_map;

    ----------------------------------------

    procedure create_items (
        p_data_type_alias in varchar2 )
    is
        l_column_alias   varchar2(30);
        l_max_cols       pls_integer;
        l_count_n        pls_integer := 0;
        l_count_vc       pls_integer := 0;
        l_count_clob     pls_integer := 0;
        l_count_d        pls_integer := 0;
        l_count_ts       pls_integer := 0;
        l_count_tstz     pls_integer := 0;
        l_count_tsltz    pls_integer := 0;
    begin
        l_max_cols :=
            case p_data_type_alias
                when c_N     then p_max_cols_number
                when c_D     then p_max_cols_date
                when c_TSLTZ then p_max_cols_timestamp_ltz
                when c_TSTZ  then p_max_cols_timestamp_tz
                when c_TS    then p_max_cols_timestamp
                when c_VC    then p_max_cols_varchar
                when c_CLOB  then p_max_cols_clob
            end;

        for i in 1 .. l_max_cols
        loop
            l_column_alias := get_column_alias(p_data_type_alias, i);

            if not l_app_items.exists(l_column_alias) then
                wwv_flow_imp_shared.create_flow_item (
                    p_flow_id          => p_app_id,
                    p_id               => wwv_flow_id.next_val,
                    p_name             => l_column_alias,
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
        l_app_items ( i.item_name ) := null; -- we need only the key
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
    l_display_order number := 10;
    l_count         number;

    ----------------------------------------

    function get_template_id (
        p_type  in varchar2,
        p_name  in varchar2,
        p_theme in number default 42)
        return number
    is
        l_return number;
    begin
        select
            template_id
        into
            l_return
        from
            apex_application_templates
        where
            application_id    = p_app_id
            and theme_number  = p_theme
            and template_type = p_type
            and template_name = p_name;
    return l_return;
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
            l_count
        from
            apex_application_page_regions
        where
            application_id  = p_app_id
            and page_id     = p_page_id
            and region_name = p_region_name;

        return case when l_count > 0 then true else false end;
    end report_exists;

    procedure create_report
    is
        l_temp_id number;
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

        l_temp_id := wwv_flow_id.next_val;

        wwv_flow_imp_page.create_worksheet (
            p_flow_id                => p_app_id,
            p_page_id                => p_page_id,
            p_id                     => l_temp_id,
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
            p_internal_uid           => l_temp_id );
    end create_report;

    ----------------------------------------

    procedure create_report_columns (
        p_data_type_alias in varchar2 )
    is
        l_column_alias     varchar2(30);
        l_column_type      varchar2(30);
        l_column_alignment varchar2(30);
        l_format_mask      varchar2(30);
        l_tz_dependent     varchar2( 1);
        l_max_cols         pls_integer;
        l_count_n          pls_integer := 0;
        l_count_d          pls_integer := 0;
        l_count_ts         pls_integer := 0;
        l_count_tstz       pls_integer := 0;
        l_count_tsltz      pls_integer := 0;
        l_count_vc         pls_integer := 0;
        l_count_clob       pls_integer := 0;
    begin
        l_max_cols :=
            case p_data_type_alias
                when c_N     then p_max_cols_number
                when c_D     then p_max_cols_date
                when c_TSLTZ then p_max_cols_timestamp_ltz
                when c_TSTZ  then p_max_cols_timestamp_tz
                when c_TS    then p_max_cols_timestamp
                when c_VC    then p_max_cols_varchar
                when c_CLOB  then p_max_cols_clob
            end;

        l_column_type :=
            case p_data_type_alias
                when c_N     then 'NUMBER'
                when c_D     then 'DATE'
                when c_TSLTZ then 'DATE'
                when c_TSTZ  then 'DATE'
                when c_TS    then 'DATE'
                when c_VC    then 'STRING'
                when c_CLOB  then 'CLOB'
            end;

        l_column_alignment :=
            case p_data_type_alias
                when c_N     then 'RIGHT'
                when c_D     then 'CENTER'
                when c_TSLTZ then 'CENTER'
                when c_TSTZ  then 'CENTER'
                when c_TS    then 'CENTER'
                when c_VC    then 'LEFT'
                when c_CLOB  then 'LEFT'
            end;

        l_format_mask :=
            case p_data_type_alias
                when c_D     then 'YYYY-MM-DD HH24:MI:SS'
                when c_TSLTZ then 'YYYY-MM-DD HH24:MI:SSXFF TZR'
                when c_TSTZ  then 'YYYY-MM-DD HH24:MI:SSXFF TZR'
                when c_TS    then 'YYYY-MM-DD HH24:MI:SSXFF'
                else              null
            end;

        l_tz_dependent :=
            case p_data_type_alias
                when c_TSLTZ then 'Y'
                else              'N'
            end;

        for i in 1 .. l_max_cols
        loop
            l_column_alias := get_column_alias(p_data_type_alias, i);

            wwv_flow_imp_page.create_worksheet_column (
                p_id                     => wwv_flow_id.next_val,
                p_db_column_name         => l_column_alias,
                p_display_order          => l_display_order,
                p_column_identifier      => l_column_alias,
                p_column_label           => '&'||l_column_alias||'.',
                p_column_type            => l_column_type,
                p_column_alignment       => l_column_alignment,
                p_format_mask            => l_format_mask,
                p_tz_dependent           => l_tz_dependent,
                p_display_condition_type => 'ITEM_IS_NOT_NULL',
                p_display_condition      => l_column_alias,
                p_use_as_row_header      => 'N',
                --disable some things for CLOBs
                p_allow_sorting          => case when l_column_type = c_CLOB then 'N' else 'Y' end,
                p_allow_ctrl_breaks      => case when l_column_type = c_CLOB then 'N' else 'Y' end,
                p_allow_aggregations     => case when l_column_type = c_CLOB then 'N' else 'Y' end,
                p_allow_computations     => case when l_column_type = c_CLOB then 'N' else 'Y' end,
                p_allow_charting         => case when l_column_type = c_CLOB then 'N' else 'Y' end,
                p_allow_group_by         => case when l_column_type = c_CLOB then 'N' else 'Y' end,
                p_allow_pivot            => case when l_column_type = c_CLOB then 'N' else 'Y' end,
                p_rpt_show_filter_lov    => case when l_column_type = c_CLOB then 'N' else 'D' end );

            l_display_order := l_display_order + 10;
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

function get_overview_counts (
    p_owner           in varchar2 default sys_context('USERENV', 'CURRENT_USER') ,
    p_objects_include in varchar2 default null ,
    p_objects_exclude in varchar2 default null ,
    p_columns_include in varchar2 default null )
    return varchar2
is
    l_return varchar2(4000);
begin
    select json_object (
           'TABLES' value
             ( select count(*)
                 from all_tables_mv t
                where owner = p_owner
                  and regexp_like (
                          table_name,
                          (select nvl(model.to_regexp_like(p_objects_include), '.*') from sys.dual),
                          'i' )
                  and not regexp_like (
                          table_name,
                          (select nvl(model.to_regexp_like(p_objects_exclude), chr(10)) from sys.dual),
                          'i' )
                  and table_name in (
                          select distinct table_name
                            from all_tab_columns_mv
                           where owner = p_owner
                             and regexp_like (
                                     column_name,
                                     (select nvl(model.to_regexp_like(p_columns_include), '.*') from sys.dual),
                                     'i') ) ),
           'TABLE_COLUMNS' value
              ( select count(*)
                  from all_tab_columns_mv
                 where owner = p_owner
                   and table_name in ( select table_name from all_tables_mv
                                        where owner = p_owner )
                   and regexp_like (
                           table_name,
                           (select nvl(model.to_regexp_like(p_objects_include), '.*') from sys.dual),
                           'i' )
                   and not regexp_like (
                           table_name,
                           (select nvl(model.to_regexp_like(p_objects_exclude), chr(10)) from sys.dual),
                           'i' )
                   and regexp_like (
                           column_name,
                           (select nvl(model.to_regexp_like(p_columns_include), '.*') from sys.dual),
                           'i') ),
           'INDEXES' value
              ( select count(*)
                  from all_indexes_mv
                 where owner = p_owner
                   and regexp_like (
                           table_name,
                           (select nvl(model.to_regexp_like(p_objects_include), '.*') from sys.dual),
                           'i' )
                   and not regexp_like (
                           table_name,
                           (select nvl(model.to_regexp_like(p_objects_exclude), chr(10)) from sys.dual),
                           'i' )
                   and index_name in (
                           select index_name
                             from all_ind_columns_mv
                            where regexp_like (
                                      column_name,
                                      (select nvl(model.to_regexp_like(p_columns_include), '.*') from sys.dual),
                                      'i') ) ),
           'VIEWS' value
              ( select count(*)
                  from all_views_mv t
                 where owner = p_owner
                   and regexp_like (
                           view_name,
                           (select nvl(model.to_regexp_like(p_objects_include), '.*') from sys.dual),
                           'i' )
                   and not regexp_like (
                           view_name,
                           (select nvl(model.to_regexp_like(p_objects_exclude), chr(10)) from sys.dual),
                           'i' )
                   and view_name in (
                           select distinct table_name
                             from all_tab_columns_mv
                            where owner = p_owner
                              and regexp_like (
                                      column_name,
                                      (select nvl(model.to_regexp_like(p_columns_include), '.*') from sys.dual),
                                      'i') ) ),
           'VIEW_COLUMNS' value
              ( select count(*)
                  from all_tab_columns_mv
                 where owner = p_owner
                   and table_name in ( select view_name from all_views_mv
                                        where owner = p_owner )
                   and regexp_like (
                           table_name,
                           (select nvl(model.to_regexp_like(p_objects_include), '.*') from sys.dual),
                           'i' )
                   and not regexp_like (
                           table_name,
                           (select nvl(model.to_regexp_like(p_objects_exclude), chr(10)) from sys.dual),
                           'i' )
                   and regexp_like (
                           column_name,
                           (select nvl(model.to_regexp_like(p_columns_include), '.*') from sys.dual),
                           'i') ),
           'M_VIEWS' value
              ( select count(*)
                  from sys.all_mviews t
                 where owner = p_owner
                   and regexp_like (
                           mview_name,
                           (select nvl(model.to_regexp_like(p_objects_include), '.*') from sys.dual),
                           'i' )
                   and not regexp_like (
                           mview_name,
                           (select nvl(model.to_regexp_like(p_objects_exclude), chr(10)) from sys.dual),
                           'i' ) ),
           'OTHER_OBJECTS' value
              ( select count(*)
                  from all_objects_mv
                 where owner = p_owner
                   and object_type not in ('TABLE', 'INDEX', 'VIEW', 'MATERIALIZED VIEW')
                   and regexp_like (
                           object_name,
                           (select nvl(model.to_regexp_like(p_objects_include), '.*') from sys.dual),
                           'i' )
                   and not regexp_like (
                           object_name,
                           (select nvl(model.to_regexp_like(p_objects_exclude), chr(10)) from sys.dual),
                           'i' ) )
      )
      into l_return
      from sys.dual;

    return l_return;
end get_overview_counts;

--------------------------------------------------------------------------------

function get_detail_counts (
    p_owner                in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
    p_object_name          in varchar2              ,
    p_model_exclude_tables in varchar2 default null )
    return varchar2
is
    l_type   varchar2(128);
    l_return varchar2(4000);
begin
    select min(object_type)
      into l_type
      from all_objects_mv
     where owner       = p_owner
       and object_name = p_object_name;

    select json_object (
           'COLUMNS' value
                case when l_type in ('TABLE', 'VIEW', 'MATERIALIZED VIEW') then
                    ( select count(*)
                        from all_tab_columns_mv
                       where owner      = p_owner
                         and table_name = p_object_name )
                    else 0
                end,
           'DATA' value
                case when l_type in ('TABLE', 'VIEW', 'MATERIALIZED VIEW') then
                    nvl ( model.get_number_of_rows ( p_owner      => p_owner,
                                                     p_table_name => p_object_name ), 0 )
                    else 0
                end,
           'MODEL' value
                ( select count(*)
                    from ( select table_name
                             from all_relations_mv
                            where owner   = p_owner and   table_name = p_object_name
                                  or
                                  r_owner = p_owner and r_table_name = p_object_name
                            union
                           select r_table_name
                             from all_relations_mv
                            where owner   = p_owner and   table_name = p_object_name
                                  or
                                  r_owner = p_owner and r_table_name = p_object_name
                            union
                           select table_name
                             from all_tables_mv
                            where owner   = p_owner and   table_name = p_object_name )
                   where not regexp_like (
                             table_name,
                             (select nvl(model.to_regexp_like(p_model_exclude_tables), chr(10)) from sys.dual),
                             'i' ) ),
           'CONSTRAINTS' value
                case when l_type in ('TABLE', 'VIEW', 'MATERIALIZED VIEW') then
                    ( select count(*)
                        from all_constraints_mv
                       where owner      = p_owner
                         and table_name = p_object_name )
                    else 0
                end,
           'INDEXES_' value
                case when l_type in ('TABLE', 'VIEW', 'MATERIALIZED VIEW') then
                    ( select count(*)
                        from all_indexes_mv
                       where owner      = p_owner
                         and table_name = p_object_name )
                    else 0
                end,
           'TRIGGERS' value
                case when l_type in ('TABLE', 'VIEW', 'MATERIALIZED VIEW') then
                    ( select count(*)
                        from all_triggers_mv
                       where owner      = p_owner
                         and table_name = p_object_name )
                    else 0
                end,
           'DEPENDS_ON' value
                ( select count(*)
                    from all_dependencies_mv
                   where owner = p_owner
                     and name  = p_object_name ),
           'REFERENCED_BY' value
                ( select count(*)
                    from all_dependencies_mv
                   where referenced_owner = p_owner
                     and referenced_name  = p_object_name ) )
      into l_return
      from sys.dual;

    return l_return;
exception when no_data_found then
    return json_object (
               'COLUMNS'       value 0 ,
               'DATA'          value 0 ,
               'MODEL'         value 0 ,
               'CONSTRAINTS'   value 0 ,
               'INDEXES_'      value 0 ,
               'TRIGGERS'      value 0 ,
               'DEPENDS_ON'    value 0 ,
               'REFERENCED_BY' value 0 );
end get_detail_counts;

--------------------------------------------------------------------------------

function get_object_meta (
    p_owner       in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
    p_object_name in varchar2 ,
    p_object_type in varchar2 default null)
    return clob
is
    l_object_type varchar2(128)   := p_object_type;
    l_html        apex_t_varchar2 := apex_t_varchar2();
    l_data        apex_t_varchar2 := apex_t_varchar2();
    --
    procedure html_push (p_text in varchar2) is
    begin
        apex_string.push(l_html, p_text);
    end html_push;
    --
    procedure data_push (p_text in varchar2) is
    begin
        apex_string.push(l_data, p_text);
    end data_push;
    --
    procedure write_section (p_name in varchar2) is
    begin
        html_push('<h4>' || p_name || '</h4>');
        if l_data.count > 0 then
            html_push('<ul>');
            for i in 1..l_data.count loop
                html_push('<li>' || l_data(i) || '</li>');
            end loop;
            l_data.delete;
            html_push('</ul>');
        else
            html_push('<p>No data found.</p>');
        end if;
    end write_section;
begin
    if p_object_name is not null then

        if l_object_type is null then
            begin
                select object_type
                  into l_object_type
                  from all_objects_mv
                 where owner       = p_owner
                   and object_name = p_object_name;
            exception
                when no_data_found then
                    return '<p>Object type not found for '||p_owner||'.'||p_object_name||'!</p>';
            end;
        end if;

        if p_object_type not in ('JOB', 'LOB', 'SYNONYM') then
                select grantee || ': ' ||
                       listagg(lower(privilege), ', ') within group (order by privilege)
                  bulk collect
                  into l_data
                  from user_tab_privs_mv
                 where owner      = p_owner
                   and table_name = p_object_name
                 group by grantee;
                write_section('Grants');
        end if;

    end if;

    return
        case when l_html.count > 0
            then apex_string.join_clob(l_html)
            else to_clob('<p>Nothing to report.</p>')
        end;
end get_object_meta;

--------------------------------------------------------------------------------

function get_bg_execution_status (
    p_execution_id in number )
    return varchar2
is
    l_json varchar2(32767);
begin
    select json_object (
           execution_id,
           process_name,
           current_process_name,
           status,
           status_code,
           status_message,
           sofar,
           totalwork,
           created_on,
           last_updated_on )
      into l_json
      from apex_appl_page_bg_proc_status
     where execution_id = p_execution_id;
    return l_json;
exception
    when no_data_found then
        return json_object (
                   'execution_id'         value null,
                   'process_name'         value null,
                   'current_process_name' value null,
                   'status'               value null,
                   'status_code'          value null,
                   'status_message'       value null,
                   'sofar'                value null,
                   'totalwork'            value null,
                   'created_on'           value null,
                   'last_updated_on'      value null );
end get_bg_execution_status;

--------------------------------------------------------------------------------

function view_missing_fk_indexes (
    p_owner varchar2 default sys_context('USERENV', 'CURRENT_USER') )
return t_indexes_tab pipelined
is
begin
    for i in (
        with excluded_owners as (
            select username from sys.all_users where oracle_maintained = 'Y'
            union all select 'ORDS_METADATA' from sys.dual
            union all select 'ORDS_PUBLIC_USER' from sys.dual ),
        needed_indexes as (
            select c.table_name,
                   listagg(cc.column_name, ', ')     within group(order by cc.position) as column_list,
                   listagg('C' || tc.column_id, '_') within group(order by cc.position) as column_ids
              from all_constraints_mv  c
              join all_cons_columns_mv cc on c.constraint_name = cc.constraint_name
              join all_tab_columns_mv  tc on c.table_name = tc.table_name and cc.column_name = tc.column_name
             where c.owner = p_owner
               and c.owner not in (select username from excluded_owners)
               and c.constraint_type = 'R'
               and c.table_name not like 'BIN$%'
             group by
                   c.table_name,
                   c.constraint_name ),
        existing_indexes as (
            select table_name,
                   listagg(column_name, ', ') within group (order by column_position) as column_list
              from all_ind_columns_mv
             where index_owner = p_owner
               and index_owner not in (select username from excluded_owners)
               and table_name not like 'BIN$%'
             group by
                   table_name,
                   index_name )
        select n.table_name,
               n.column_list as needed_index_columns,
               n.table_name || '_' || n.column_ids || '_FK_IX' as index_name,
               case when e.column_list is null then
                   'create index ' || n.table_name || '_' || n.column_ids || '_FK_IX' ||
                   ' on ' || n.table_name || ' (' || n.column_list || ')'
               end as ddl
          from needed_indexes        n
          left join existing_indexes e on n.table_name = e.table_name
                and instr(e.column_list, n.column_list) = 1
         where e.column_list is null
         order by table_name, needed_index_columns )
    loop
        pipe row (i);
    end loop;
end view_missing_fk_indexes;

--------------------------------------------------------------------------------

procedure create_missing_fk_indexes
is
    l_totalwork       pls_integer;
    l_missing_indexes t_indexes_tab;
    l_base_mviews     model.t_vc2_tab := model.base_mviews;
begin
    select * bulk collect into l_missing_indexes
      from table (model_joel.view_missing_fk_indexes);

    if l_missing_indexes.count = 0 then

        apex_background_process.set_status(
            p_message => 'No foreign key indexes missing, stopping now...' );
        apex_background_process.set_progress(
            p_totalwork => 1,
            p_sofar     => 1 );

    else

        l_totalwork := l_missing_indexes.count + l_base_mviews.count;
        apex_background_process.set_progress(
            p_totalwork => l_totalwork,
            p_sofar     => 0 );

        for i in 1..l_missing_indexes.count loop
            apex_background_process.set_status(
                p_message => 'Creating ' || l_missing_indexes(i).index_name );

            execute immediate l_missing_indexes(i).ddl;

            apex_background_process.set_progress(
                p_totalwork => l_totalwork,
                p_sofar     => i );
        end loop;

        create_or_refresh_base_mviews (
            p_totalwork => l_totalwork,
            p_sofar     => l_missing_indexes.count );

    end if;
end create_missing_fk_indexes;

--------------------------------------------------------------------------------

procedure create_or_refresh_base_mviews (
    p_totalwork integer default null,
    p_sofar     integer default null )
is
    l_base_mviews model.t_vc2_tab := model.base_mviews;
    l_totalwork   pls_integer := coalesce(p_totalwork, l_base_mviews.count);
    l_sofar       pls_integer := coalesce(p_sofar    , 0);
begin
    apex_background_process.set_progress(
        p_totalwork => l_totalwork,
        p_sofar     => l_sofar );

    for i in 1..l_base_mviews.count loop
        apex_background_process.set_status(
            p_message => 'Refreshing ' || l_base_mviews(i) || '_MV' );

        model.create_or_refresh_mview( l_base_mviews(i), 'SYS' );

        apex_background_process.set_progress(
            p_totalwork => l_totalwork,
            p_sofar     => l_sofar + i );
    end loop;
end create_or_refresh_base_mviews;


--------------------------------------------------------------------------------

end model_joel;
/

-- check for errors in package model_joel
declare
  l_count pls_integer;
  l_name  varchar2(30) := 'MODEL_JOEL';
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


prompt - FINISHED
