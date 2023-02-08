create or replace package model authid current_user is

c_name    constant varchar2 (30 byte) := 'Oracle Data Model Utilities';
c_version constant varchar2 (10 byte) := '0.6.0';
c_url     constant varchar2 (34 byte) := 'https://github.com/ogobrecht/model';
c_license constant varchar2 ( 3 byte) := 'MIT';
c_author  constant varchar2 (15 byte) := 'Ottmar Gobrecht';

/**

Oracle Data Model Utilities
===========================

PL/SQL utilities to support data model activities like query/mview
generation, reporting, visualizations...

**/

--------------------------------------------------------------------------------
-- PUBLIC MODEL METHODS
--------------------------------------------------------------------------------

procedure create_or_refresh_mview (
    p_table_name    in varchar2,
    p_owner         in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
    p_mview_prefix  in varchar2 default null,
    p_mview_postfix in varchar2 default '_MV' );
/**

Create or refresh a materialized view for the given table or view name.

EXAMPLES

```sql
-- log is written to serveroutput, so we enable it here
set serveroutput on

-- with default postfix _MV in own schema
exec model.create_or_refresh_mview('MY_TABLE');

-- with custom postfix in foreign schema
begin
    model.create_or_refresh_mview (
        p_table_name    => 'USER_TAB_COLUMNS',
        p_owner         => 'SYS'
        p_mview_postfix => '_MVIEW' );
end;
{{/}}
```

**/

--------------------------------------------------------------------------------

procedure drop_mview (
    p_mview_name in varchar2 );
/**

Drop a materialized view.

EXAMPLE

```sql
exec model.drop_mview('USER_TAB_COLUMNS_MV');
```
**/

--------------------------------------------------------------------------------

function get_data_default_vc (
    p_dict_tab_name in varchar2,
    p_table_name    in varchar2,
    p_column_name   in varchar2,
    p_owner         in varchar2 default sys_context('USERENV', 'CURRENT_USER') )
    return varchar2;
/**

Returns the LONG column DATA_DEFAULT as varchar2(4000).

Is used in `create_dict_mviews`. Works only for the dictionary tables
USER_TAB_COLUMNS, USER_TAB_COLS, ALL_TAB_COLUMNS, ALL_TAB_COLS,
USER_NESTED_TABLE_COLS, ALL_NESTED_TABLE_COLS.

**/

--------------------------------------------------------------------------------

function get_search_condition_vc (
    p_dict_tab_name   in varchar2,
    p_constraint_name in varchar2,
    p_owner           in varchar2 default sys_context('USERENV', 'CURRENT_USER') )
    return varchar2;
/**

Returns the LONG column SEARCH_CONDITION as varchar2(4000).

Is used in `create_dict_mviews`. Works only for the dictionary_tables
USER_CONSTRAINTS, ALL_CONSTRAINTS

**/

--------------------------------------------------------------------------------

function get_table_query (
    p_table_name  in varchar2,
    p_owner       in varchar2 default sys_context('USERENV', 'CURRENT_USER') )
    return varchar2;
/**

Get the query for a given table.

EXAMPLE

```sql
select model.get_table_query('EMP') from dual;
```

**/

--------------------------------------------------------------------------------

function get_table_headers (
    p_table_name  in varchar2,
    p_owner       in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
    p_delimiter   in varchar2 default ':',
    p_lowercase   in boolean  default true )
    return varchar2;
/**

Get the column headings for a given table as a delimited string.

EXAMPLE

```sql
select model.get_table_headers('EMP') from dual;
```

**/

--------------------------------------------------------------------------------

function version return varchar2;
/**

Returns the version information from the model package.

EXAMPLE

```sql
select model.version from dual;
```

**/

--------------------------------------------------------------------------------

end model;
/
