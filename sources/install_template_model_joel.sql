set define on
set serveroutput on
set verify off
set feedback off
set linesize 240
set trimout on
set trimspool on
whenever sqlerror exit sql.sqlcode rollback

exec model.create_dict_mviews('all_tab_columns');
prompt
prompt ORACLE DATA MODEL UTILITIES - CREATE APEX EXTENSION PACKAGE
prompt - Project page https://github.com/ogobrecht/model
@set_ccflags.sql
prompt - Package model_joel (spec)
@model_joel.pks
prompt - Package model_joel (body)
@model_joel.pkb
@show_errors_model_joel.sql
prompt - FINISHED

--exec apex_session.create_session(100, 1, 'OGOBRECH');
--exec model_joel.create_application_items(100);
--exec model_joel.create_interactive_report(100,1);

