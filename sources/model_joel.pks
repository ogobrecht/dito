create or replace package model_joel authid current_user is

/**

Oracle Data Model Utilities - APEX Extension
============================================

Helpers to support a generic Interactive Report to show the data of all
tables.

**/

function get_table_query (
    p_table_name             in varchar2,
    p_schema_name            in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
    p_max_cols_varchar       in integer default 20,
    p_max_cols_number        in integer default 20,
    p_max_cols_date          in integer default 20,
    p_max_cols_timestamp     in integer default 20,
    p_max_cols_timestamp_tz  in integer default 20,
    p_max_cols_timestamp_ltz in integer default 20 )
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

end model_joel;
/
