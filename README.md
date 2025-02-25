# Oracle Data Model Utilities

PL/SQL utilities to support data model activities like reporting,
visualizations...

This project is in an early stage...

We have one core package called MODEL and one APEX extension package. It was
first called MODEL_APEX, but for the [#JoelKallmanDay][1] in 2022 I renamed
it to MODEL_JOEL. Thank you for this initiative, [Tim (@oraclebase)][2]. This
project is about data model tools, but Joel was a role model for the APEX
community, so MODEL_JOEL sounds good to me. And it will always remind me of
Joel when I work on this open source project in my spare time...

[1]: https://oracle-base.com/blog/2022/09/27/joel-kallman-day-2022-announcement/
[2]: https://twitter.com/oraclebase

## What we have so far

Package model:

- Procedures to create, refresh and drop materialized views on dictionary
  tables to speed up queries on it
- Functions to get the query for a table and its column names as a delimited
  string

Package model_joel with APEX specific functionality:

- Procedures and functions to support the usage of an Interactive Report as a
  generic data viewer for different tables and views

## Installation

Clone or download the project from GitHub, start your SQL tool and run the
core installation script:

```sql
@install/core.sql
```

If you have APEX installed and want to use the APEX extension, then install
it also:

```sql
@install/apex_extension.sql
```

## Docs

Have a look in the subfolder docs - there we have a Markdown file for each
package.

## Changelog

- 0.9.1 (2024-11-16):
  - Create base mviews only when needed on installation
  - Update node dependencies
- 0.9.0 (2024-11-15):
  - Make base mview array private
  - Show installation errors in anonymous block instead of SQL query
- 0.8.0 (2024-04-05):
  - Handle list of base mviews in model spec
  - Add custom base view: ALL_RELATIONS
  - Run initial base view creation only ones
  - Some cleanup
- 0.7.3 (2023-12-26):
  - Remove model.create_dict_mviews and refresh_dict_mviews
  - Add model.create_or_refresh_mview
  - Improve APEX Interactive Report support in model_joel
- 0.6.0 (2022-10-05): Rename package back to model, add APEX extension package (model_joel)
- 0.5.0 (2022-10-02): Rename package from model to dito, rework project structure
- 0.4.0 (2022-03-05): New methods get_table_query and get_table_headers
- 0.3.0 (2021-10-28): New helper methods get_data_default_vc, get_search_condition_vc
- 0.2.1 (2021-10-24): Fix error on unknown tables, add elapsed time to output, reformat code
- 0.2.0 (2021-10-23): Add a param for custom tab lists, improved docs
- 0.1.0 (2021-10-22): Initial minimal version
