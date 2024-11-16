prompt ORACLE DATA MODEL UTILITIES - APEX EXTENSION PACKAGE

set define on
set serveroutput on
set verify off
set feedback off
set linesize 240
set trimout on
set trimspool on
whenever sqlerror exit sql.sqlcode rollback

prompt - Create or refresh needed mviews (this can take a minute or so...)
begin
    if model.all_base_mviews_exist then
        dbms_output.put_line('- Mviews already existing - nothing to do');
    else
        model.create_or_refresh_base_mviews;
    end if;
end;
/

prompt - Set compiler flags
@set_ccflags.sql

prompt - Package model_joel (spec)
@model_joel.pks

prompt - Package model_joel (body)
@model_joel.pkb

@show_errors_model_joel.sql

prompt - FINISHED
