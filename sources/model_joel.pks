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
