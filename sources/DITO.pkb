create or replace package body dito is

--------------------------------------------------------------------------------

function utl_cleanup_tabs_list (
  p_tabs_list in varchar2 )
  return varchar2
is
begin
  return trim(both ',' from regexp_replace(regexp_replace(p_tabs_list, '\s+'), ',{2,}', ','));
end;

--------------------------------------------------------------------------------

function runtime (
  p_start in timestamp )
  return varchar2
is
  v_runtime varchar2(30 byte);
begin
  v_runtime := to_char(localtimestamp - p_start);
  return substr(v_runtime, instr(v_runtime,':')-2, 15);
end runtime;

--------------------------------------------------------------------------------

function utl_runtime_seconds (
  p_start in timestamp )
  return number
is
  v_runtime interval day to second;
begin
  v_runtime := localtimestamp - p_start;
  return
    extract(hour   from v_runtime) * 3600 +
    extract(minute from v_runtime) *   60 +
    extract(second from v_runtime)        ;
end utl_runtime_seconds;

--------------------------------------------------------------------------------

function utl_create_dict_mview (
  p_table_name in varchar2 )
  return integer
is
  v_table_name varchar2(1000 byte);
  v_mview_name varchar2(1000 byte);
  v_sql        varchar2(32767 byte);
  v_return     pls_integer := 0;
begin
  v_table_name := lower(trim(substr(p_table_name, 1, 1000)));
  v_mview_name := v_table_name || '_mv';
  for i in (
    with base as (
      select table_name, column_name, data_type, data_length
        from all_tab_cols
       where owner = 'SYS'
         and table_name = upper(v_table_name)
       order by column_id
    )
    select table_name,
           column_name,
           data_type,
           data_length,
           case when data_type = 'LONG' then (
             select count(*)
               from base
              where column_name = t.column_name || '_VC')
           end as vc_column_exists
      from base t
  )
  loop
    v_sql := v_sql || '  ' ||
      case when i.data_type != 'LONG' then
        lower(i.column_name) || ',' || chr(10)
        else
          'to_lob(' || lower(i.column_name) || ') as ' || lower(i.column_name) || ',' || chr(10) ||
          case when i.vc_column_exists = 0 then
            case i.column_name
              when 'DATA_DEFAULT' then
                '  case when data_default is not null then dito.get_data_default_vc(p_dict_tab_name=>''' || v_table_name ||
                  ''',p_table_name=>table_name,p_column_name=>column_name' ||
                  case when v_table_name like 'all%' then ',p_owner=>owner' end ||
                  ') end as ' || lower(i.column_name) || '_vc,' || chr(10)
              when 'SEARCH_CONDITION' then
                '  case when search_condition is not null then dito.get_search_conditions_vc(p_dict_tab_name=>''' || v_table_name ||
                  ''',p_table_name=>table_name,p_constraint_name=>constraint_name,p_owner=>owner' ||
                  ') end as ' || lower(i.column_name) || '_vc,' || chr(10)
            end
          end
      end;
  end loop;
  if v_sql is not null then
    v_return := 1;
    v_sql    := 'create materialized view ' || v_mview_name || ' as ' || chr(10) ||
                    'select'                                          || chr(10) ||
                    rtrim(v_sql, ',' || chr(10))                      || chr(10) ||
                    'from'                                            || chr(10) ||
                    '  ' || v_table_name;
    --dbms_output.put_line(v_sql);
    dbms_output.put_line('- ' || v_mview_name);
    execute immediate(v_sql);
  end if;
  return v_return;
end utl_create_dict_mview;

--------------------------------------------------------------------------------

procedure create_dict_mviews (
  p_dict_tabs_list in varchar2 default c_dict_tabs_list )
is
  v_start          timestamp := localtimestamp;
  v_dict_tabs_list varchar2(32767 byte)    := utl_cleanup_tabs_list(p_dict_tabs_list);
  v_count          pls_integer     := 0;
begin
  dbms_output.put_line('DITO - CREATE DICT MVIEWS');
  for i in (
    -- https://blogs.oracle.com/sql/post/split-comma-separated-values-into-rows-in-oracle-database
    with
    base as ( select v_dict_tabs_list as str from dual ),
    tabs as (
       select regexp_replace(upper(trim(regexp_substr(str, '[^,]+', 1, level))), '_MV$') as table_name
         from base
      connect by level <= length(str) - length(replace(str, ',')) + 1
    )
    select table_name from tabs
    minus
    select regexp_replace(mview_name, '_MV$') from user_mviews where regexp_like (mview_name, '_MV$')
  )
  loop
    v_count := v_count + utl_create_dict_mview(i.table_name);
  end loop;
  dbms_output.put_line('- ' || v_count || ' mview' || case when v_count != 1 then 's' end || ' created in ' || runtime(v_start));

end create_dict_mviews;

--------------------------------------------------------------------------------

procedure refresh_dict_mviews (
  p_dict_tabs_list in varchar2 default c_dict_tabs_list )
is
  v_start          timestamp            := localtimestamp;
  v_dict_tabs_list varchar2(32767 byte) := utl_cleanup_tabs_list(p_dict_tabs_list);
  v_count          pls_integer          := 0;
begin
  dbms_output.put_line('DITO - REFRESH DICT MVIEWS');
  for i in (
    with
    base as ( select v_dict_tabs_list as str from dual ),
    tabs as (
       select regexp_replace(upper(trim(regexp_substr(str, '[^,]+', 1, level))), '_MV$') as table_name
         from base
      connect by level <= length(str) - length(replace(str, ',')) + 1
    ),
    expected_mviews as ( select table_name || '_MV' as mview_name from tabs )
    select mview_name from expected_mviews natural join user_mviews
  )
  loop
    dbms_output.put_line('- ' || lower(i.mview_name));
    dbms_mview.refresh(list => i.mview_name, method => 'c');
    v_count := v_count + 1;
  end loop;
  dbms_output.put_line('- ' || v_count || ' mview' || case when v_count != 1 then 's' end || ' refreshed in ' || runtime(v_start));
end refresh_dict_mviews;

--------------------------------------------------------------------------------

procedure drop_dict_mviews (
  p_dict_tabs_list in varchar2 default c_dict_tabs_list )
is
  v_start          timestamp            := localtimestamp;
  v_dict_tabs_list varchar2(32767 byte) := utl_cleanup_tabs_list(p_dict_tabs_list);
  v_count          pls_integer          := 0;
begin
  dbms_output.put_line('DITO - DROP DICT MVIEWS');
  for i in(
    with
    base as ( select v_dict_tabs_list as str from dual ),
    tabs as (
       select regexp_replace(upper(trim(regexp_substr(str, '[^,]+', 1, level))), '_MV$') as table_name
         from base
      connect by level <= length(str) - length(replace(str, ',')) + 1
    ),
    expected_mviews as ( select table_name || '_MV' as table_name from tabs )
    select mview_name from expected_mviews join user_mviews on table_name = mview_name )
  loop
    dbms_output.put_line('- ' || lower(i.mview_name));
    execute immediate 'drop materialized view ' || i.mview_name;
    v_count := v_count + 1;
  end loop;
  dbms_output.put_line('- ' || v_count || ' mview' || case when v_count != 1 then 's' end || ' dropped in ' || runtime(v_start));
end drop_dict_mviews;

--------------------------------------------------------------------------------

function get_data_default_vc (
  p_dict_tab_name varchar2,
  p_table_name    varchar2,
  p_column_name   varchar2,
  p_owner         varchar2 default user)
  return varchar2
is
  v_long long;
begin
  case
    when upper(p_dict_tab_name) in ('USER_TAB_COLUMNS', 'USER_TAB_COLS') then
      select data_default into v_long
        from user_tab_columns
       where table_name = upper(p_table_name)
         and column_name = upper(p_column_name);
    when upper(p_dict_tab_name) in ('ALL_TAB_COLUMNS', 'ALL_TAB_COLS') then
      select data_default into v_long
        from all_tab_columns
       where owner = p_owner
         and table_name = upper(p_table_name)
         and column_name = upper(p_column_name);
    when upper(p_dict_tab_name) = 'USER_NESTED_TABLE_COLS' then
      select data_default into v_long
        from user_nested_table_cols
       where table_name = upper(p_table_name)
         and column_name = upper(p_column_name);
    when upper(p_dict_tab_name) = 'ALL_NESTED_TABLE_COLS' then
      select data_default into v_long
        from all_nested_table_cols
       where owner = p_owner
         and table_name = upper(p_table_name)
         and column_name = upper(p_column_name);
    else
      raise_application_error(-20999, 'Unsupported dictionary table ' || p_dict_tab_name);
  end case;
  return substr(v_long, 1, 4000);
end get_data_default_vc;

--------------------------------------------------------------------------------

function get_search_condition_vc (
  p_dict_tab_name   in varchar2,
  p_constraint_name in varchar2,
  p_owner           in varchar2 default user )
  return varchar2
is
  v_long long;
begin
  case upper(p_dict_tab_name)
    when 'USER_CONSTRAINTS' then
      select search_condition into v_long
        from user_constraints
       where owner = p_owner
         and constraint_name = upper(p_constraint_name);
    when 'ALL_CONSTRAINTS' then
      select search_condition into v_long
        from all_constraints
       where owner = p_owner
         and constraint_name = upper(p_constraint_name);
    else
      raise_application_error(-20999, 'Unsupported dictionary table ' || p_dict_tab_name);
  end case;
  return substr(v_long, 1, 4000);
end get_search_condition_vc;

--------------------------------------------------------------------------------

function get_table_query (
  p_table_name  in varchar2,
  p_schema_name in varchar2 default sys_context('USERENV', 'CURRENT_USER') )
  return varchar2
is
  v_return varchar2( 32767 ) := 'select ';
begin
  for i in ( select *
               from all_tab_columns
              where owner      = p_schema_name
                and table_name = p_table_name
              order by column_id )
  loop
    v_return := v_return || i.column_name || ', ';
  end loop;

  return rtrim( v_return, ', ' ) || ' from ' || p_table_name;
end get_table_query;

--------------------------------------------------------------------------------

function get_table_headers (
  p_table_name  in varchar2,
  p_schema_name in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
  p_delimiter   in varchar2 default ':',
  p_lowercase   in boolean  default true )
  return varchar2
is
  v_return varchar2(32767);
begin
  for i in ( select *
               from all_tab_columns
              where owner      = p_schema_name
                and table_name = p_table_name
              order by column_id )
  loop
    v_return := v_return ||
                case
                  when p_lowercase
                  then lower( i.column_name )
                  else i.column_name
                end ||
                p_delimiter;
  end loop;

  return rtrim( v_return, p_delimiter );
end get_table_headers;

--------------------------------------------------------------------------------

function version return varchar2 is
begin
  return c_version;
end version;

--------------------------------------------------------------------------------

end dito;
/