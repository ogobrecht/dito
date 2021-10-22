set define on
set serveroutput on
set verify off
set feedback off
set linesize 240
set trimout on
set trimspool on
whenever sqlerror exit sql.sqlcode rollback

prompt ORACLE DATA MODEL UTILITIES: CREATE DATABASE OBJECTS
prompt - Project page https://github.com/ogobrecht/model
prompt - Package MODEL (spec)
@MODEL.pks
prompt - Package MODEL (body)
@MODEL.pkb
prompt - FINISHED

