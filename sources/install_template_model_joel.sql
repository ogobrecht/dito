set define on
set serveroutput on
set verify off
set feedback off
set linesize 240
set trimout on
set trimspool on
whenever sqlerror exit sql.sqlcode rollback

exec dbms_output.put_line( 'ORACLE DATA MODEL UTILITIES - CREATE APEX EXTENSION PACKAGE' );
exec dbms_output.put_line( '- Create or refresh needed mviews:' );
exec model.create_or_refresh_mview('ALL_TABLES'     , 'SYS');
exec model.create_or_refresh_mview('ALL_TAB_COLUMNS', 'SYS');
exec model.create_or_refresh_mview('ALL_CONSTRAINTS', 'SYS');
exec model.create_or_refresh_mview('ALL_INDEXES'    , 'SYS');
exec model.create_or_refresh_mview('ALL_OBJECTS'    , 'SYS');
exec model.create_or_refresh_mview('ALL_VIEWS'      , 'SYS');
exec model.create_or_refresh_mview('ALL_TRIGGERS'   , 'SYS');
@set_ccflags.sql
exec dbms_output.put_line( '- Package model_joel (spec)' );
@model_joel.pks
exec dbms_output.put_line( '- Package model_joel (body)' );
@model_joel.pkb
@show_errors_model_joel.sql
exec dbms_output.put_line( '- FINISHED' );
