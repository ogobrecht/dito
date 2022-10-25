create or replace package model_joel authid current_user is

/**

Oracle Data Model Utilities - APEX Extension
============================================

Helpers to support a generic Interactive Report to show the data of any
table.

**/

--------------------------------------------------------------------------------

function get_table_query (
    p_table_name             in varchar2            ,
    p_max_cols_number        in integer  default 20 ,
    p_max_cols_date          in integer  default  5 ,
    p_max_cols_timestamp_ltz in integer  default  5 ,
    p_max_cols_timestamp_tz  in integer  default  5 ,
    p_max_cols_timestamp     in integer  default  5 ,
    p_max_cols_varchar       in integer  default 20 ,
    p_max_cols_clob          in integer  default  5 )
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

--------------------------------------------------------------------------------

procedure set_session_state (
    p_table_name             in varchar2            , -- you can prepend the schema: my_schema.my_table (default is sys_context('USERENV', 'CURRENT_USER'))
    p_max_cols_number        in integer  default 20 ,
    p_max_cols_date          in integer  default  5 ,
    p_max_cols_timestamp_ltz in integer  default  5 ,
    p_max_cols_timestamp_tz  in integer  default  5 ,
    p_max_cols_timestamp     in integer  default  5 ,
    p_max_cols_varchar       in integer  default 20 ,
    p_max_cols_clob          in integer  default  5 );
/**

set the session state of application items for a given table. The state is then
used for conditional display of report columns as well for the report headers.

EXAMPLE

```sql
model_joel.set_session_state(p_table_name => 'CONSOLE_LOGS');
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
        p_max_cols_varchar       =>  40 ,
        p_max_cols_clob          =>  10 );
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
        p_max_cols_number        =>  40 ,
        p_max_cols_date          =>  10 ,
        p_max_cols_timestamp_ltz =>  10 ,
        p_max_cols_timestamp_tz  =>  10 ,
        p_max_cols_timestamp     =>  10 ,
        p_max_cols_varchar       =>  40 ,
        p_max_cols_clob          =>  10 );
end;
{{/}}
```

**/
--------------------------------------------------------------------------------

end model_joel;
/
