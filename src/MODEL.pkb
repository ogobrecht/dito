create or replace package body model is

  --------------------------------------------------------------------------------

  function utl_cleanup_tabs_list(p_tabs_list varchar2) return varchar2 is
  begin
    return trim(both ',' from regexp_replace(regexp_replace(p_tabs_list, '\s+'), ',{2,}', ','));
  end;

  procedure utl_create_dict_mview(p_table_name varchar2) is
    v_table_name varchar2(1000);
    v_mview_name varchar2(1000);
    v_sql        varchar2(32767);
  begin
    v_table_name := lower(trim(substr(p_table_name, 1, 1000)));
    v_mview_name := v_table_name || '_mv';
    for i in(
      select table_name, column_name, data_type, data_length
        from all_tab_cols
       where owner = 'SYS'
         and table_name = upper(v_table_name)
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
               || v_mview_name
               || ' as '
               || chr(10)
               || 'select'
               || chr(10)
               || rtrim(v_sql, ','
                 || chr(10))
               || chr(10)
               || 'from'
               || chr(10)
               || '  '
               || v_table_name;
    end if;
    --dbms_output.put_line(v_sql);
    execute immediate(v_sql);
  end utl_create_dict_mview;

  --------------------------------------------------------------------------------

  procedure create_dict_mviews(
    p_dict_tabs_list varchar2 default c_dict_tabs_list
  ) is
    v_dict_tabs_list varchar2(32767) := utl_cleanup_tabs_list(p_dict_tabs_list);
    v_count          pls_integer     := 0;
  begin
    dbms_output.put_line('MODEL - CREATE DICT MVIEWS');
    for i in(
      -- https://blogs.oracle.com/sql/post/split-comma-separated-values-into-rows-in-oracle-database
      with base as(
          select v_dict_tabs_list as str from dual
        )
      , tabs as(
          select regexp_replace(upper(trim(regexp_substr(str, '[^,]+', 1, level))), '_MV$') as table_name
            from base
         connect by level <= length(str) - length(replace(str, ',')) + 1
        )
      select table_name
        from tabs
      minus
      select regexp_replace(mview_name, '_MV$')
        from user_mviews
       where regexp_like (mview_name, '_MV$')
    )
    loop

      dbms_output.put_line('- '
        || lower(i.table_name)
        || '_mv');
      utl_create_dict_mview(i.table_name);
      v_count := v_count + 1;
    end loop;
    dbms_output.put_line('- '
      || v_count
      || ' mview'
      || case
        when v_count != 1 then
          's'
      end
      || ' created');

  end create_dict_mviews;
  
  --------------------------------------------------------------------------------

  procedure refresh_dict_mviews(
    p_dict_tabs_list varchar2 default c_dict_tabs_list
  ) is
    v_dict_tabs_list varchar2(32767) := utl_cleanup_tabs_list(p_dict_tabs_list);
    v_count          pls_integer     := 0;
  begin
    dbms_output.put_line('MODEL - REFRESH DICT MVIEWS');
    for i in (
      with base as(
          select v_dict_tabs_list as str from dual
        )
      , tabs as(
          select regexp_replace(upper(trim(regexp_substr(str, '[^,]+', 1, level))), '_MV$') as table_name
            from base
         connect by level <= length(str) - length(replace(str, ',')) + 1
        ), expected_mviews as (
          select table_name || '_MV' as mview_name
            from tabs
        )
      select mview_name
        from expected_mviews
     natural join user_mviews
    )
    loop
      dbms_output.put_line('- ' || lower(i.mview_name));
      dbms_mview.refresh(list => i.mview_name, method => 'c');
      v_count := v_count + 1;
    end loop;
    dbms_output.put_line('- '
      || v_count
      || ' mview'
      || case
        when v_count != 1 then
          's'
      end
      || ' refreshed');
  end refresh_dict_mviews;
  
  --------------------------------------------------------------------------------

  procedure drop_dict_mviews(
    p_dict_tabs_list varchar2 default c_dict_tabs_list
  ) is
    v_dict_tabs_list varchar2(32767) := utl_cleanup_tabs_list(p_dict_tabs_list);
    v_count          pls_integer     := 0;
  begin
    dbms_output.put_line('MODEL - DROP DICT MVIEWS');
    for i in(
      with base as(
          select v_dict_tabs_list as str from dual
        )
      , tabs as(
          select regexp_replace(upper(trim(regexp_substr(str, '[^,]+', 1, level))), '_MV$') as table_name
            from base
         connect by level <= length(str) - length(replace(str, ',')) + 1
        ), expected_mviews as (
          select table_name || '_MV' as table_name
            from tabs
        )
      select mview_name
        from expected_mviews
        join user_mviews
          on table_name = mview_name
    )
    loop
      dbms_output.put_line('- ' || lower(i.mview_name));
      execute immediate 'drop materialized view ' || i.mview_name;
      v_count := v_count + 1;
    end loop;
    dbms_output.put_line('- '
      || v_count
      || ' mview'
      || case
        when v_count != 1 then
          's'
      end
      || ' dropped');
  end drop_dict_mviews;

  --------------------------------------------------------------------------------

end model;
/