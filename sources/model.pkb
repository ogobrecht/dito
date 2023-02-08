create or replace package body model is

c_lf            constant char(1)      := chr(10);
c_error_code    constant pls_integer  := -20777 ;
c_assert_prefix constant varchar2(30) := 'Assertion failed: ';

--------------------------------------------------------------------------------

procedure assert (
    p_expression in boolean  ,
    p_message    in varchar2 )
is
begin
    if not p_expression then
        raise_application_error(
            c_error_code,
            c_assert_prefix || p_message,
            true);
    end if;
end assert;

--------------------------------------------------------------------------------

procedure raise_error (
    p_message    in varchar2 )
is
begin
    raise_application_error(
        c_error_code,
        c_assert_prefix || p_message,
        true);
end raise_error;

--------------------------------------------------------------------------------

function runtime (
    p_start in timestamp )
    return varchar2
is
    v_runtime varchar2(30 byte);
begin
    v_runtime := to_char(localtimestamp - p_start);
    return substr(v_runtime, instr(v_runtime,':')+1, 12);
end runtime;

--------------------------------------------------------------------------------

procedure create_or_refresh_mview (
    p_table_name    in varchar2,
    p_owner         in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
    p_mview_prefix  in varchar2 default null,
    p_mview_postfix in varchar2 default '_MV' )
is
    v_mview_name varchar2(32767);
    v_count      pls_integer;
    v_code       clob;
    v_start      timestamp := localtimestamp;
begin
    v_mview_name := p_mview_prefix || p_table_name || p_mview_postfix;
    assert (
        length(v_mview_name) <= 128,
        'The resulting materialized view name is longer then 128 characters (' ||
            to_char(length(v_mview_name)) ||
            ' characters: ' ||
            v_mview_name );

    select count(*)
      into v_count
      from user_mviews
     where mview_name = v_mview_name;

    if v_count = 1 then

        dbms_mview.refresh (
            list => v_mview_name,
            method => 'c' );
        dbms_output.put_line (
            '- ' || runtime(v_start) ||
            ' - materialized view refreshed - ' ||
            v_mview_name );

    else

        select count(*)
          into v_count
          from all_tab_columns
         where owner = p_owner
           and table_name = p_table_name;

        assert (
            v_count > 0,
            'The given table or view is not accessible for the current user or does not exist.' );

        for i in (
            with base as (
              select table_name, column_name, data_type, data_length
                from all_tab_columns
               where owner = p_owner
                 and table_name = p_table_name
               order by column_id )
            select table_name,
                   column_name,
                   data_type,
                   data_length,
                   case when data_type = 'LONG' then (
                     select count(*)
                       from base
                      where column_name = t.column_name || '_VC')
                   end as vc_column_exists
              from base t )
        loop
            v_code := v_code || '  ' ||
                case
                    when i.data_type != 'LONG' then
                        i.column_name || ',' || c_lf
                    else
                        'to_lob(' || i.column_name || ') as ' ||
                        i.column_name || ',' || c_lf ||
                        case when i.vc_column_exists = 0 then
                            case i.column_name
                                when 'DATA_DEFAULT' then
                                    '  case when data_default is not null then ' ||
                                    'model.get_data_default_vc(' ||
                                    'p_dict_tab_name=>''' || p_table_name ||
                                    ''',p_table_name=>table_name,' ||
                                    'p_column_name=>column_name' ||
                                    case
                                        when p_table_name like 'ALL%' then
                                            ',p_owner=>owner'
                                    end ||
                                    ') end as ' || i.column_name || '_vc,' || c_lf
                                when 'SEARCH_CONDITION' then
                                    '  case when search_condition is not null then ' ||
                                    'model.get_search_conditions_vc(' ||
                                    'p_dict_tab_name=>''' || p_table_name ||
                                    ''',p_table_name=>table_name,' ||
                                    'p_constraint_name=>constraint_name,' ||
                                    'p_owner=>owner' ||
                                    ') end as ' || i.column_name || '_vc,' || c_lf
                            end
                        end
                end;
        end loop;

        if v_code is not null then
            v_code   := 'create materialized view ' || v_mview_name
                            || ' as '                     || c_lf
                            || 'select'                   || c_lf
                            || rtrim(v_code, ',' || c_lf) || c_lf
                            || 'from'                     || c_lf
                            || '  ' || p_table_name;
            --dbms_output.put_line(v_code);
            execute immediate(v_code);

        end if;

        dbms_output.put_line (
            '- ' || runtime(v_start) ||
            ' - materialized view created - ' || v_mview_name);
    end if;


end create_or_refresh_mview;

--------------------------------------------------------------------------------

procedure drop_mview (
    p_mview_name in varchar2 )
is
    v_count pls_integer;
    v_sql   varchar2(1000);
    v_start timestamp := localtimestamp;
begin

    select count(*)
      into v_count
      from user_mviews
     where mview_name = p_mview_name;

    if v_count = 1 then
        v_sql := 'drop materialized view ' || p_mview_name;
        dbms_output.put_line (
            '- ' || runtime(v_start) ||
            ' - materialized view dropped - ' || p_mview_name);
        execute immediate v_sql;
    else
        dbms_output.put_line (
            '- ' || runtime(v_start) ||
            ' - materialized view does not exist - ' || p_mview_name);
    end if;

end drop_mview;

--------------------------------------------------------------------------------

function get_data_default_vc (
    p_dict_tab_name varchar2,
    p_table_name    varchar2,
    p_column_name   varchar2,
    p_owner         varchar2 default sys_context('USERENV', 'CURRENT_USER') )
    return varchar2
is
    v_long long;
begin
    case
        when upper(p_dict_tab_name) in ('USER_TAB_COLUMNS', 'USER_TAB_COLS') then
            select data_default
              into v_long
              from user_tab_columns
             where table_name  = upper(p_table_name)
               and column_name = upper(p_column_name);
        when upper(p_dict_tab_name) in ('ALL_TAB_COLUMNS', 'ALL_TAB_COLUMNS') then
            select data_default
              into v_long
              from all_tab_columns
             where owner       = p_owner
               and table_name  = upper(p_table_name)
               and column_name = upper(p_column_name);
        when upper(p_dict_tab_name) = 'USER_NESTED_TABLE_COLS' then
            select data_default
              into v_long
              from user_nested_table_cols
             where table_name  = upper(p_table_name)
               and column_name = upper(p_column_name);
        when upper(p_dict_tab_name) = 'ALL_NESTED_TABLE_COLS' then
            select data_default
              into v_long
              from all_nested_table_cols
             where owner       = p_owner
               and table_name  = upper(p_table_name)
               and column_name = upper(p_column_name);
        else
            raise_error('Unsupported dictionary table ' || p_dict_tab_name);
    end case;

    return substr(v_long, 1, 4000);
end get_data_default_vc;

--------------------------------------------------------------------------------

function get_search_condition_vc (
    p_dict_tab_name   in varchar2,
    p_constraint_name in varchar2,
    p_owner           in varchar2 default sys_context('USERENV', 'CURRENT_USER') )
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
        raise_error('Unsupported dictionary table ' || p_dict_tab_name);
    end case;

    return substr(v_long, 1, 4000);
end get_search_condition_vc;

--------------------------------------------------------------------------------

function get_table_query (
    p_table_name  in varchar2,
    p_owner       in varchar2 default sys_context('USERENV', 'CURRENT_USER') )
    return varchar2
is
    v_return varchar2( 32767 ) := 'select ';
begin
    for i in ( select *
                 from all_tab_columns
                where owner      = p_owner
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
    p_owner       in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
    p_delimiter   in varchar2 default ':',
    p_lowercase   in boolean  default true )
    return varchar2
is
    v_return varchar2(32767);
begin
    for i in ( select *
                 from all_tab_columns
                where owner      = p_owner
                  and table_name = p_table_name
                order by column_id )
    loop
        v_return := v_return
            || case when p_lowercase then i.column_name else i.column_name end
            || p_delimiter;
  end loop;

  return rtrim(v_return, p_delimiter);
end get_table_headers;

--------------------------------------------------------------------------------

function version return varchar2 is
begin
    return c_version;
end version;

--------------------------------------------------------------------------------

end model;
/