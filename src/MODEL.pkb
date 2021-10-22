create or replace package body model is

  c_dict_tables constant varchar2(100) :=
    'tables,tab_columns,constraints,cons_columns,tab_comments,mview_comments,col_comments';

  --------------------------------------------------------------------------------

  procedure create_dict_mviews is
  begin
    for i in(
      with base as(
          select c_dict_tables as str from dual
        )
      , tabs as(
          select upper(trim(regexp_substr(str, '[^,]+', 1, level))) as val
            from base
         connect by level <= length(str) - length(replace(str, ',')) + 1
        )
      select 'USER_' || val as table_name
        from tabs
      union
      select 'ALL_' || val as table_name
        from tabs
      minus
      select regexp_replace(object_name, '_MV$')
        from user_objects
       where regexp_like (object_name, '_MV$')
    )
    loop
      utl_create_dict_mview(i.table_name);
    end loop;
  end create_dict_mviews;
  
  --------------------------------------------------------------------------------

  procedure drop_dict_mviews is
  begin
    for i in(
      with base as(
          select c_dict_tables as str from dual
        )
      , tabs as(
          select upper(trim(regexp_substr(str, '[^,]+', 1, level))) as val
            from base
         connect by level <= length(str) - length(replace(str, ',')) + 1
        ), expected_mviews as (
          select 'USER_'
                 || val
                 || '_MV' as table_name
            from tabs
          union
          select 'ALL_'
                 || val
                 || '_MV' as table_name
            from tabs
        )
      select mview_name
        from expected_mviews
        join user_mviews
          on table_name = mview_name
    )
    loop
      execute immediate 'drop materialized view ' || i.mview_name;
    end loop;
  end drop_dict_mviews;
  
  --------------------------------------------------------------------------------

  procedure refresh_dict_mviews is
    v_mview_list varchar2(32767);
  begin
    with base as(
        select c_dict_tables as str from dual
      )
    , tabs as(
        select upper(trim(regexp_substr(str, '[^,]+', 1, level))) as val
          from base
       connect by level <= length(str) - length(replace(str, ',')) + 1
      ), expected_mviews as (
        select 'USER_'
               || val
               || '_MV' as table_name
          from tabs
        union
        select 'ALL_'
               || val
               || '_MV' as table_name
          from tabs
      )
    select listagg(mview_name, ',') into v_mview_list
      from expected_mviews
      join user_mviews
        on table_name = mview_name;
    if v_mview_list is not null then
      dbms_mview.refresh(list => v_mview_list, method => 'c');
    end if;
  end refresh_dict_mviews;

  --------------------------------------------------------------------------------

  procedure utl_create_dict_mview(p_table_name varchar2) is
    v_table_name varchar2(1000);
    v_sql        varchar2(32767);
  begin
    v_table_name := upper(trim(substr(p_table_name, 1, 1000)));
    for i in(
      select table_name, column_name, data_type, data_length
        from all_tab_cols
       where owner = 'SYS'
         and table_name = v_table_name
       order by column_id
    )
    loop
      v_sql := v_sql
               || '  '
               || case
                 when i.data_type != 'LONG' then
                   lower(i.column_name)
                 else
                   'to_lob('
                   || lower(i.column_name)
                   || ') as '
                   || lower(i.column_name)
               end
               || ','
               || chr(10);
    end loop;
    if v_sql is not null then
      v_sql := 'create materialized view '
               || lower(v_table_name)
               || '_mv as '
               || chr(10)
               || 'select'
               || chr(10)
               || rtrim(v_sql, ','
                 || chr(10))
               || chr(10)
               || 'from'
               || chr(10)
               || '  '
               || lower(v_table_name);
    end if;
    --dbms_output.put_line(v_sql);
    execute immediate(v_sql);
  end utl_create_dict_mview;

  --------------------------------------------------------------------------------

end model;
/