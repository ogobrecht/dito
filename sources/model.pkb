create or replace package body model is

c_lf            constant char(1)           := chr(10);
c_error_code    constant pls_integer       := -20777 ;
c_assert_prefix constant varchar2(30)      := 'Assertion failed: ';

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
    l_runtime varchar2(30 byte);
begin
    l_runtime := to_char(localtimestamp - p_start);
    return substr(l_runtime, instr(l_runtime,':')+1, 12);
end runtime;

--------------------------------------------------------------------------------

procedure create_or_refresh_mview (
    p_table_name    in varchar2,
    p_owner         in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
    p_mview_prefix  in varchar2 default null,
    p_mview_postfix in varchar2 default '_MV',
    p_debug         in boolean  default false )
is
    l_mview_name varchar2(32767);
    l_count      pls_integer;
    l_code       clob;
    l_start      timestamp := localtimestamp;
    type r_comments is record (
        column_name varchar2(128),
        comments    varchar2(4000) );
    type t_comments is table of r_comments index by pls_integer;
    l_comments t_comments := t_comments();
begin
    l_mview_name := p_mview_prefix || p_table_name || p_mview_postfix;
    assert (
        length(l_mview_name) <= 128,
        'The resulting materialized view name is longer then 128 characters (' ||
            to_char(length(l_mview_name)) || ' characters: ' || l_mview_name );

    select count(*)
      into l_count
      from user_mviews
     where mview_name = l_mview_name;

    if l_count = 1 then

        dbms_mview.refresh (
            list => l_mview_name,
            method => 'c' );
        dbms_output.put_line (
            '- ' || runtime(l_start) ||
            ' - materialized view refreshed - ' ||
            l_mview_name );

    else

        select count(*)
          into l_count
          from all_tab_columns
         where owner = p_owner
           and table_name = p_table_name;

        assert (
            l_count > 0,
            'The given table or view is not accessible for the current user or does not exist.' );

        for i in (
            with base as (
              select owner, table_name, column_name, data_type, data_length
                from all_tab_columns
               where owner = p_owner
                 and table_name = p_table_name
               order by column_id )
            select owner,
                   table_name,
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
            -- convert LONG columns to CLOB
            if i.data_type != 'LONG' then
                l_code := l_code ||
                    '  t.' || i.column_name || ',' || c_lf;
            else
                l_code := l_code ||
                    '  ' || 'to_lob(t.' || i.column_name || ') as ' ||
                    i.column_name || ',' || c_lf;
            end if;

            -- add additional xxx_VC columns for LONG columns in case of dictionary tables
            if i.owner = 'SYS' and i.data_type = 'LONG' and i.vc_column_exists = 0 then
                l_code := l_code ||
                    case i.column_name
                        when 'DATA_DEFAULT' then
                            '  case when data_default is not null then'              || c_lf ||
                            '    model.get_data_default_vc ('                        || c_lf ||
                            '      p_dict_tab_name => ''' || p_table_name || ''','   || c_lf ||
                            '      p_table_name    => t.table_name,'                 || c_lf ||
                            '      p_column_name   => t.column_name'                 ||
                            case when p_table_name like 'ALL%' then
                                     ',' || c_lf ||
                                     '      p_owner         => t.owner'
                            end || ' )'                                              || c_lf ||
                            '  end as data_default_vc,'                              || c_lf
                        when 'SEARCH_CONDITION' then
                            '  case when search_condition is not null then'          || c_lf ||
                            '    model.get_search_conditions_vc ('                   || c_lf ||
                            '      p_dict_tab_name   => ''' || p_table_name || ''',' || c_lf ||
                            '      p_table_name      => t.table_name,'               || c_lf ||
                            '      p_constraint_name => t.constraint_name,'          || c_lf ||
                            '      p_owner           => t.owner'                     || c_lf ||
                            '    ) end as search_condition_vc,'                      || c_lf
                        when 'TRIGGER_BODY' then
                            '  model.get_trigger_body_vc ('                          || c_lf ||
                            '    p_dict_tab_name => ''' || p_table_name || ''','     || c_lf ||
                            '    p_trigger_name  => t.trigger_name '                 ||
                            case when p_table_name like 'ALL%' then
                                     ',' || c_lf ||
                                     '    p_owner         => t.owner'
                            end || ' )'                                              || c_lf ||
                            '  as trigger_body_vc,'                                  || c_lf
                    end;

                l_comments(l_comments.count + 1) := r_comments (
                    column_name => i.column_name || '_VC',
                    comments    => rtrim (
                        get_column_comments (
                            p_table_name  => p_table_name,
                            p_column_name => i.column_name,
                            p_owner       => 'SYS' ),
                        '. ' ) ||
                        '. Varchar2 representation (possibly truncated).' ) ;
            end if;

            -- add COMMENTS after TABLE_NAME or VIEW_NAME in case of dictionary tables
            if  i.owner = 'SYS'
                and (
                    i.table_name in ('ALL_TABLES','USER_TABLES') and i.column_name = 'TABLE_NAME'
                    or
                    i.table_name in ('ALL_VIEWS','USER_VIEWS')   and i.column_name = 'VIEW_NAME'
                    )
            then
                l_code := l_code || '  c.comments,' || c_lf;

                --l_code := l_code ||
                --    '  model.get_table_comments ('      || c_lf ||
                --    '    p_table_name => t.table_name,' || c_lf ||
                --    '    p_owner      => t.owner )'     || c_lf ||
                --    '  as comments, '                   || c_lf;

                l_comments(l_comments.count + 1) := r_comments (
                    column_name => 'COMMENTS',
                    comments    => 'Comments on this table or view.' ) ;
            end if;

            -- add column COMMENTS after column DATA_TYPE in case of dictionary tables
            if  i.owner = 'SYS'
                and i.table_name in ('ALL_TAB_COLUMNS','USER_TAB_COLUMNS')
                and i.column_name = 'DATA_TYPE'
            then
                l_code := l_code || '  c.comments,' || c_lf;

                --l_code := l_code ||
                --    '  model.get_column_comments ('       || c_lf ||
                --    '    p_table_name  => t.table_name,'  || c_lf ||
                --    '    p_column_name => t.column_name,' || c_lf ||
                --    '    p_owner       => t.owner )'      || c_lf ||
                --    '  as comments, '                     || c_lf;

                l_comments(l_comments.count + 1) := r_comments (
                    column_name => 'COMMENTS',
                    comments    => 'Comments on the column.' ) ;
            end if;

            -- add IDENTITY_GENERATION_TYPE after column IDENTITY_COLUMN in case of dictionary tables
            if  i.owner = 'SYS'
                and i.column_name = 'IDENTITY_COLUMN'
                and i.table_name in ( 'USER_TAB_COLUMNS',
                                      'ALL_TAB_COLUMNS' )
            then
                l_code := l_code || '  i.generation_type as identity_generation_type,' || c_lf;

                --l_code := l_code ||
                --    '  case when identity_column = ''YES'' then' || c_lf ||
                --    '    model.get_identity_generation_type ('   || c_lf ||
                --    '    p_table_name  => t.table_name,'         || c_lf ||
                --    '    p_column_name => t.column_name,'        || c_lf ||
                --    '    p_owner       => t.owner )'             || c_lf ||
                --    '  end as identity_generation_type, '        || c_lf;

                l_comments(l_comments.count + 1) := r_comments (
                    column_name => 'IDENTITY_GENERATION_TYPE',
                    comments    => 'Generation type of the identity column. Possible values are ALWAYS or BY DEFAULT.' ) ;
            end if;

        end loop;

        if l_code is not null then
            l_code :=
                'create materialized view ' || l_mview_name || ' as ' || c_lf ||
                'select'                                              || c_lf ||
                rtrim(l_code, ',' || c_lf)                            || c_lf ||
                'from'                                                || c_lf ||
                '  ' || p_table_name || ' t'                          || c_lf ||
                case when p_owner = 'SYS' and p_table_name in (
                                                'ALL_TAB_COLUMNS',
                                                'ALL_TABLES',
                                                'ALL_VIEWS',
                                                'USER_TAB_COLUMNS',
                                                'USER_TABLES',
                                                'USER_VIEWS' ) then
                    '  left join ' ||
                    case p_table_name
                        when 'ALL_TAB_COLUMNS' then
                            'all_col_comments c'                    || c_lf ||
                            '    on  t.owner       = c.owner'       || c_lf ||
                            '    and t.table_name  = c.table_name'  || c_lf ||
                            '    and t.column_name = c.column_name'
                        when 'ALL_TABLES' then
                            'all_tab_comments c'                    || c_lf ||
                            '    on  t.owner      = c.owner'        || c_lf ||
                            '    and t.table_name = c.table_name'
                        when 'ALL_VIEWS' then
                            'all_tab_comments c'                    || c_lf ||
                            '    on  t.owner     = c.owner'         || c_lf ||
                            '    and t.view_name = c.table_name'
                        when 'USER_TAB_COLUMNS' then
                            'user_col_comments c'                   || c_lf ||
                            '    on  t.table_name  = c.table_name'  || c_lf ||
                            '    and t.column_name = c.column_name'
                        when 'USER_TABLES' then
                            'user_tab_comments c'                   || c_lf ||
                            '    on t.table_name = c.table_name'
                        when 'USER_VIEWS' then
                            'user_tab_comments c'                   || c_lf ||
                            '    on t.view_name = c.table_name'
                    end || c_lf
                end ||
                case when p_owner = 'SYS' and p_table_name in (
                                                'ALL_TAB_COLUMNS',
                                                'USER_TAB_COLUMNS' ) then
                    '  left join ' ||
                    case p_table_name
                        when 'USER_TAB_COLUMNS' then
                            'user_tab_identity_cols i'              || c_lf ||
                            '    on  t.table_name  = i.table_name'  || c_lf ||
                            '    and t.column_name = i.column_name'
                        when 'ALL_TAB_COLUMNS' then
                            'all_tab_identity_cols i'               || c_lf ||
                            '    on  t.owner       = i.owner'       || c_lf ||
                            '    and t.table_name  = i.table_name'  || c_lf ||
                            '    and t.column_name = i.column_name'
                    end || c_lf
                end
                ;

            if p_debug then
                dbms_output.put_line(l_code);
            end if;

            execute immediate(l_code);

            -- copy over table/view comments
            for i in ( select *
                         from all_tab_comments
                        where owner      = p_owner
                          and table_name = p_table_name )
            loop
                execute immediate 'comment on materialized view ' || l_mview_name ||
                                  ' is ''' || replace(i.comments,'''', '''''') || '''';
            end loop;

            -- copy over column comments
            for i in ( select *
                         from all_col_comments
                        where owner      = p_owner
                          and table_name = p_table_name )
            loop
                execute immediate 'comment on column ' || l_mview_name || '.' || i.column_name ||
                                  ' is ''' || replace(i.comments,'''', '''''') || '''';
            end loop;

            -- add comments for additional columns
            for i in 1 .. l_comments.count
            loop
                execute immediate 'comment on column ' || l_mview_name || '.' || l_comments(i).column_name ||
                                  ' is ''' || replace(l_comments(i).comments,'''', '''''')  || '''';
            end loop;

        end if;

        dbms_output.put_line (
            '- ' || runtime(l_start) ||
            ' - materialized view created - ' || l_mview_name);
    end if;

end create_or_refresh_mview;

--------------------------------------------------------------------------------

procedure drop_mview (
    p_mview_name in varchar2 )
is
    l_count pls_integer;
    l_sql   varchar2(1000);
    l_start timestamp := localtimestamp;
begin

    select count(*)
      into l_count
      from user_mviews
     where mview_name = p_mview_name;

    if l_count = 1 then
        l_sql := 'drop materialized view ' || p_mview_name;
        dbms_output.put_line (
            '- ' || runtime(l_start) ||
            ' - materialized view dropped - ' || p_mview_name);
        execute immediate l_sql;
    else
        dbms_output.put_line (
            '- ' || runtime(l_start) ||
            ' - materialized view does not exist - ' || p_mview_name);
    end if;

end drop_mview;

--------------------------------------------------------------------------------

function get_table_comments (
    p_table_name in varchar2,
    p_owner      in varchar2 default sys_context('USERENV', 'CURRENT_USER') )
    return varchar2
is
    l_comments varchar2(32767);
begin
    select comments
      into l_comments
      from all_tab_comments
     where owner      = p_owner
       and table_name = p_table_name;

    return l_comments;
exception
    when no_data_found
        then return null;
end get_table_comments;


--------------------------------------------------------------------------------

function get_column_comments (
    p_table_name  in varchar2,
    p_column_name in varchar2,
    p_owner       in varchar2 default sys_context('USERENV', 'CURRENT_USER') )
    return varchar2
is
    l_comments varchar2(32767);
begin
    select comments
      into l_comments
      from all_col_comments
     where owner       = p_owner
       and table_name  = p_table_name
       and column_name = p_column_name;

    return l_comments;
exception
    when no_data_found
        then return null;
end get_column_comments;

--------------------------------------------------------------------------------

function get_number_of_rows (
    p_table_name  in varchar2,
    p_owner       in varchar2 default sys_context('USERENV', 'CURRENT_USER') )
    return integer
is
    l_num_rows integer;
begin
    if p_table_name is not null then
        execute immediate 'select count(*) from ' || p_owner || '.' || p_table_name
            into l_num_rows;
    end if;
    return l_num_rows;
end get_number_of_rows;
--------------------------------------------------------------------------------

function get_identity_generation_type (
    p_table_name  in varchar2,
    p_column_name in varchar2,
    p_owner       in varchar2 default sys_context('USERENV', 'CURRENT_USER') )
    return varchar2
is
    l_generation_type varchar2(32767);
begin
    select generation_type
      into l_generation_type
      from all_tab_identity_cols
     where owner       = p_owner
       and table_name  = p_table_name
       and column_name = p_column_name;

    return l_generation_type;
exception
    when no_data_found then
        return null;
end get_identity_generation_type;

--------------------------------------------------------------------------------

function get_data_default_vc (
    p_dict_tab_name varchar2,
    p_table_name    varchar2,
    p_column_name   varchar2,
    p_owner         varchar2 default sys_context('USERENV', 'CURRENT_USER') )
    return varchar2
is
    l_dict_tab_name varchar2(128) := upper(p_dict_tab_name);
    l_table_name    varchar2(128) := upper(p_table_name);
    l_column_name   varchar2(128) := upper(p_column_name);
    l_long          long;
begin
    case
        when l_dict_tab_name in ('USER_TAB_COLUMNS', 'USER_TAB_COLS') then
            select data_default
              into l_long
              from user_tab_columns
             where table_name  = l_table_name
               and column_name = l_column_name;
        when l_dict_tab_name in ('ALL_TAB_COLUMNS', 'ALL_TAB_COLUMNS') then
            select data_default
              into l_long
              from all_tab_columns
             where owner       = p_owner
               and table_name  = l_table_name
               and column_name = l_column_name;
        when l_dict_tab_name = 'USER_NESTED_TABLE_COLS' then
            select data_default
              into l_long
              from user_nested_table_cols
             where table_name  = l_table_name
               and column_name = l_column_name;
        when l_dict_tab_name = 'ALL_NESTED_TABLE_COLS' then
            select data_default
              into l_long
              from all_nested_table_cols
             where owner       = p_owner
               and table_name  = l_table_name
               and column_name = l_column_name;
        else
            raise_error('Unsupported dictionary table ' || p_dict_tab_name);
    end case;

    return substr(l_long, 1, 4000);
end get_data_default_vc;

--------------------------------------------------------------------------------

function get_search_condition_vc (
    p_dict_tab_name   in varchar2,
    p_constraint_name in varchar2,
    p_owner           in varchar2 default sys_context('USERENV', 'CURRENT_USER') )
    return varchar2
is
    l_dict_tab_name   varchar2(128) := upper(p_dict_tab_name);
    l_constraint_name varchar2(128) := upper(p_constraint_name);
    l_long            long;
begin
    case l_dict_tab_name
        when 'USER_CONSTRAINTS' then
            select search_condition into l_long
              from user_constraints
             where owner = p_owner
               and constraint_name = l_constraint_name;
        when 'ALL_CONSTRAINTS' then
            select search_condition into l_long
              from all_constraints
             where owner = p_owner
               and constraint_name = l_constraint_name;
        else
        raise_error('Unsupported dictionary table ' || p_dict_tab_name);
    end case;

    return substr(l_long, 1, 4000);
end get_search_condition_vc;

--------------------------------------------------------------------------------

function get_trigger_body_vc (
    p_dict_tab_name in varchar2,
    p_trigger_name  in varchar2,
    p_owner         in varchar2 default sys_context('USERENV', 'CURRENT_USER') )
    return varchar2
is
    l_dict_tab_name varchar2(128) := upper(p_dict_tab_name);
    l_trigger_name  varchar2(128) := upper(p_trigger_name);
    l_long          long;
begin
    case l_dict_tab_name
        when 'USER_TRIGGERS' then
            select trigger_body into l_long
              from user_triggers
             where trigger_name = l_trigger_name;
        when 'ALL_TRIGGERS' then
            select trigger_body into l_long
              from all_triggers
             where owner        = p_owner
               and trigger_name = l_trigger_name;
        else
        raise_error('Unsupported dictionary table ' || p_dict_tab_name);
    end case;

    return substr(l_long, 1, 4000);
end get_trigger_body_vc;

--------------------------------------------------------------------------------

function get_table_query (
    p_table_name  in varchar2,
    p_owner       in varchar2 default sys_context('USERENV', 'CURRENT_USER') )
    return varchar2
is
    l_return varchar2( 32767 ) := 'select ';
begin
    for i in ( select *
                 from all_tab_columns
                where owner      = p_owner
                  and table_name = p_table_name
                order by column_id )
    loop
        l_return := l_return || i.column_name || ', ';
    end loop;

    return rtrim( l_return, ', ' ) || ' from ' || p_table_name;
end get_table_query;

--------------------------------------------------------------------------------

function get_table_headers (
    p_table_name  in varchar2,
    p_owner       in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
    p_delimiter   in varchar2 default ':',
    p_lowercase   in boolean  default true )
    return varchar2
is
    l_return varchar2(32767);
begin
    for i in ( select *
                 from all_tab_columns
                where owner      = p_owner
                  and table_name = p_table_name
                order by column_id )
    loop
        l_return := l_return
            || case when p_lowercase then i.column_name else i.column_name end
            || p_delimiter;
  end loop;

  return rtrim(l_return, p_delimiter);
end get_table_headers;

--------------------------------------------------------------------------------

function to_regexp_like (
    p_like  in varchar2 )
    return varchar2 deterministic
is
    l_return       varchar2(32767) := p_like;
    l_has_brackets boolean         := false;
    l_has_commas   boolean         := false;
begin
    -- check for brackets
    if instr(l_return, '(') > 0 then
        l_has_brackets := true;
    end if;

    -- process comma
    if instr(l_return, ',') > 0 then
        l_has_commas := true;
        l_return     := regexp_replace(l_return, '\s*,\s*', '|');
    end if;

    -- process star
    l_return := replace(l_return, '*', '.*');

    -- process percent
    l_return := replace(l_return, '%', '.*');

    -- process multiple like pattern
    if l_has_commas and not l_has_brackets then
        l_return := '(' || l_return || ')';
    end if;

    return l_return;
end to_regexp_like;

--------------------------------------------------------------------------------

function version return varchar2 is
begin
    return c_version;
end version;

--------------------------------------------------------------------------------

end model;
/