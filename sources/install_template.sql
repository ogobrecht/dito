set define on
set serveroutput on
set verify off
set feedback off
set linesize 240
set trimout on
set trimspool on
whenever sqlerror exit sql.sqlcode rollback

prompt ORACLE DICTIONARY TOOLS: CREATE DATABASE OBJECTS
prompt - Project page https://github.com/ogobrecht/dito
@set_ccflags.sql
prompt - Package DITO (spec)
@DITO.pks
prompt - Package DITO (body)
@DITO.pkb
@show_errors.sql
@log_installed_version.sql

