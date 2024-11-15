prompt ORACLE DATA MODEL UTILITIES - CORE PACKAGE
prompt - Project page https://github.com/ogobrecht/model

set define on
set serveroutput on
set verify off
set feedback off
set linesize 240
set trimout on
set trimspool on
whenever sqlerror exit sql.sqlcode rollback

prompt - Set compiler flags
@set_ccflags.sql

prompt - Package model (spec)
@model.pks

prompt - Package model (body)
@model.pkb

@show_errors_model.sql

@log_installed_version.sql

prompt - FINISHED
