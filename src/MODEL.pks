create or replace package model authid current_user is

c_name    constant varchar2 ( 30 byte ) := 'Oracle Data Model Utilities'        ;
c_version constant varchar2 ( 10 byte ) := '0.3.0'                              ;
c_url     constant varchar2 ( 34 byte ) := 'https://github.com/ogobrecht/model' ;
c_license constant varchar2 (  3 byte ) := 'MIT'                                ;
c_author  constant varchar2 ( 15 byte ) := 'Ottmar Gobrecht'                    ;

c_dict_tabs_list constant varchar2 (200 byte) := '
  user_tables         ,
  user_tab_columns    ,
  user_constraints    ,
  user_cons_columns   ,
  user_tab_comments   ,
  user_mview_comments ,
  user_col_comments   ,
';

/**

Oracle Data Model Utilities
===========================

PL/SQL utilities to support data model activities like reporting, visualizations...

This project is in an early stage - use it at your own risk...

CHANGELOG

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
-- PUBLIC MODEL METHODS
--------------------------------------------------------------------------------

procedure create_dict_mviews (
  p_dict_tabs_list varchar2 default c_dict_tabs_list
);
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
  p_dict_tabs_list varchar2 default c_dict_tabs_list
);
/**

Refresh the materialized views.

Same rules and defaults as for the `create_dict_mviews` method (see above).

If you created a custum set of mviews you should provide the same parameter
value here for the refresh.

**/

--------------------------------------------------------------------------------

procedure drop_dict_mviews (
  p_dict_tabs_list varchar2 default c_dict_tabs_list
);
/**

Drop the materialized views.

Same rules and defaults as for the `create_dict_mviews` method (see above).

If you created a custum set of mviews you should provide the same parameter
value here for the drop.

**/

--------------------------------------------------------------------------------

function get_data_default_vc (
  p_dict_tab_name varchar2,
  p_table_name    varchar2,
  p_column_name   varchar2,
  p_owner         varchar2 default user)
  return varchar2;
/**

Convert the LONG column DATA_DEFAULT to varchar2(4000).

Is used in `create_dict_mviews`. Works only for the dictionary tables
USER_TAB_COLUMNS, USER_TAB_COLS, ALL_TAB_COLUMNS, ALL_TAB_COLS,
USER_NESTED_TABLE_COLS, ALL_NESTED_TABLE_COLS.

**/

--------------------------------------------------------------------------------

function get_search_condition_vc (
  p_dict_tab_name   varchar2,
  p_constraint_name varchar2,
  p_owner           varchar2 default user)
  return varchar2;
/**

Convert the LONG column SEARCH_CONDITION to varchar2(4000).

Is used in `create_dict_mviews`. Works only for the dictionary_tables
USER_CONSTRAINTS, ALL_CONSTRAINTS

**/

--------------------------------------------------------------------------------

end model;
/
