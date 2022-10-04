set define on
set serveroutput on
set verify off
set feedback off
set linesize 240
set trimout on
set trimspool on
whenever sqlerror exit sql.sqlcode rollback

exec dito.create_dict_mviews('all_tab_columns');
prompt
prompt ORACLE DICTIONARY TOOLS - CREATE APEX EXTENSION PACKAGE
prompt - Project page https://github.com/ogobrecht/dito
@set_ccflags.sql
prompt - Package dito_apex (spec)
@dito_apex.pks
prompt - Package dito_apex (body)
@dito_apex.pkb
@show_errors_dito_apex.sql
prompt - FINISHED

