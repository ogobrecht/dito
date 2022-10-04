set define on
set serveroutput on
set verify off
set feedback off
set linesize 240
set trimout on
set trimspool on
whenever sqlerror exit sql.sqlcode rollback

prompt ORACLE DICTIONARY TOOLS - CREATE CORE PACKAGE
prompt - Project page https://github.com/ogobrecht/dito
@set_ccflags.sql
prompt - Package dito (spec)
@dito.pks
prompt - Package dito (body)
@dito.pkb
@show_errors_dito.sql
@log_installed_version.sql

