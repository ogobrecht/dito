create or replace package model authid current_user is

c_name    constant varchar2 (30 byte) := 'Oracle Data Model Utilities';
c_version constant varchar2 (10 byte) := '0.6.0';
c_url     constant varchar2 (34 byte) := 'https://github.com/ogobrecht/model';
c_license constant varchar2 ( 3 byte) := 'MIT';
c_author  constant varchar2 (15 byte) := 'Ottmar Gobrecht';

c_dict_tabs_list constant varchar2 (1000 byte) := '
    all_tables       ,
    all_tab_columns  ,
    all_constraints  ,
    all_cons_columns ,
    all_indexes      ,
    all_ind_columns  ,
    all_tab_comments ,
    all_col_comments ,
';

/**

Oracle Data Model Utilities
===========================

PL/SQL utilities to support data model activities like reporting, visualizations...

**/

--------------------------------------------------------------------------------
-- PUBLIC MODEL METHODS
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
exec model.create_dict_mviews;

-- with custom data dictionary table list
exec model.create_dict_mviews('all_tables, all_tab_columns');

-- works also when you provide the resulting mviev names instead
-- of the table names or when you have line breaks in your list
begin
    model.create_dict_mviews('
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

Returns the LONG column DATA_DEFAULT as varchar2(4000).

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

Returns the LONG column SEARCH_CONDITION as varchar2(4000).

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

EXAMPLE

```sql
select model.get_table_query('EMP') from dual;
```

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
