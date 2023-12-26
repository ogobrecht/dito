set define on
set serveroutput on
set verify off
set feedback off
set linesize 240
set trimout on
set trimspool on
whenever sqlerror exit sql.sqlcode rollback

exec dbms_output.put_line( 'ORACLE DATA MODEL UTILITIES - CREATE CORE PACKAGE' );
exec dbms_output.put_line( '- Project page https://github.com/ogobrecht/model' );
@set_ccflags.sql
exec dbms_output.put_line( '- Package model (spec)' );
@model.pks
exec dbms_output.put_line( '- Package model (body)' );
@model.pkb
@show_errors_model.sql
@log_installed_version.sql
