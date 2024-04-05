create or replace package body model is

c_lf            constant char(1)           := chr(10);
c_error_code    constant pls_integer       := -20777 ;
c_assert_prefix constant varchar2(30)      := 'Assertion failed: ';

--------------------------------------------------------------------------------

function list_base_mviews return t_vc2_tab pipelined
is
begin
    for i in 1..g_base_mviews.count loop
        pipe row(g_base_mviews(i));
    end loop;
end list_base_mviews;

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
      from sys.user_mviews
     where mview_name = l_mview_name;

    if l_count = 1 then

        sys.dbms_snapshot.refresh (
            list   => l_mview_name,
            method => 'c' );
        sys.dbms_output.put_line (
            '- ' || runtime(l_start) ||
            ' - materialized view refreshed - ' ||
            l_mview_name );

    elsif p_table_name = 'ALL_RELATIONS' and p_owner = 'SYS' then

        execute immediate q'[
            create materialized view all_relations_mv as
            with constraint_not_null_columns as (
                --> because of primary keys and not null check constraints we have to select distinct here
                select distinct
                       owner,
                       table_name,
                       column_name,
                       nullable
                  from ( select c.owner,
                                c.table_name,
                                cc.column_name,
                                c.constraint_name,
                                c.constraint_type,
                                c.search_condition,
                                'N' as nullable
                           from all_constraints_mv  c
                           join all_cons_columns_mv cc
                             on c.owner           = cc.owner
                            and c.constraint_name = cc.constraint_name
                          where c.status = 'ENABLED'
                                and ( c.constraint_type = 'P'
                                      or --------------------
                                      c.constraint_type = 'C'
                                      and regexp_count( trim(c.search_condition),
                                                        '^"{0,1}' || cc.column_name || '"{0,1}\s+is\s+not\s+null$',
                                                        1,
                                                        'i' ) = 1 ) ) ),
            table_columns as (
                select tc.owner,
                       tc.table_name,
                       tc.column_name,
                       tc.data_type,
                       tc.data_length,
                       tc.data_precision,
                       tc.data_scale,
                       tc.char_length,
                       tc.char_used,
                       tc.nullable as nullable_dict, --> dictionary does not recognize table level not null constraints
                       nvl( nn.nullable, 'Y' ) as nullable_cons
                  from all_tab_columns_mv                    tc
                       left join constraint_not_null_columns nn
                         on tc.owner       = nn.owner
                        and tc.table_name  = nn.table_name
                        and tc.column_name = nn.column_name ),
            relations as (
                select c.owner,
                       c.constraint_name,
                       c.deferrable,
                       c.status,
                       c.validated,
                       cc.table_name,
                       cc.column_name,
                       cc.position,
                       upper(substr(tc.data_type,1,1)) || lower(substr(tc.data_type,2)) ||
                           case
                             when tc.data_type in ('CHAR', 'NCHAR', 'VARCHAR2', 'NVARCHAR2') then
                               ' (' || tc.char_length || case tc.char_used when 'B' then ' byte' when 'C' then ' char' end || ')'
                             when tc.data_type = 'NUMBER' and tc.data_precision is not null and tc.data_scale is not null then
                               ' (' || tc.data_precision || ',' || tc.data_scale || ')'
                           end
                       as data_type_display,
                       tc.nullable_dict,
                       tc.nullable_cons,
                       r_c.owner           as r_owner,
                       r_c.constraint_name as r_constraint_name,
                       r_c.deferrable      as r_deferrable,
                       r_c.status          as r_status,
                       r_c.validated       as r_validated,
                       r_cc.table_name     as r_table_name,
                       r_cc.column_name    as r_column_name,
                       r_cc.position       as r_position,
                       upper(substr(r_tc.data_type,1,1)) || lower(substr(r_tc.data_type,2)) ||
                           case
                             when r_tc.data_type in ('CHAR', 'NCHAR', 'VARCHAR2', 'NVARCHAR2') then
                               ' (' || r_tc.char_length || case r_tc.char_used when 'B' then ' byte' when 'C' then ' char' end || ')'
                             when r_tc.data_type = 'NUMBER' and r_tc.data_precision is not null and r_tc.data_scale is not null then
                               ' (' || r_tc.data_precision || ',' || r_tc.data_scale || ')'
                           end
                       as r_data_type_display,
                       r_tc.nullable_dict  as r_nullable_dict,
                       r_tc.nullable_cons  as r_nullable_cons
                  from all_constraints_mv c
                       --
                  join all_cons_columns_mv cc
                    on c.owner           = cc.owner
                   and c.constraint_name = cc.constraint_name
                       --
                  left join table_columns tc
                    on cc.owner       = tc.owner
                   and cc.table_name  = tc.table_name
                   and cc.column_name = tc.column_name
                       --
                  join all_constraints_mv r_c
                    on c.r_owner           = r_c.owner
                   and c.r_constraint_name = r_c.constraint_name
                       --
                  join all_cons_columns_mv r_cc
                    on r_c.owner           = r_cc.owner
                   and r_c.constraint_name = r_cc.constraint_name
                       --
                  left join table_columns r_tc
                    on r_cc.owner       = r_tc.owner
                   and r_cc.table_name  = r_tc.table_name
                   and r_cc.column_name = r_tc.column_name
                       --
                 where c.constraint_type = 'R' )
            select * from relations]';

            create_index(l_mview_name, 'IDX1', 'OWNER,TABLE_NAME');
            create_index(l_mview_name, 'IDX2', 'R_OWNER,R_TABLE_NAME');

    else

        select count(*)
          into l_count
          from sys.all_tab_columns
         where owner = p_owner
           and table_name = p_table_name;

        assert (
            l_count > 0,
            'The given table or view is not accessible for the current user or does not exist.' );

        for i in (
            with base as (
              select owner, table_name, column_name, data_type, data_length, column_id
                from sys.all_tab_columns
               where owner = p_owner
                 and table_name = p_table_name )
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
              from base t
             order by column_id )
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
                '  ' || p_owner || '.' || p_table_name || ' t'        || c_lf ||
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
                            'sys.all_col_comments c'                || c_lf ||
                            '    on  t.owner       = c.owner'       || c_lf ||
                            '    and t.table_name  = c.table_name'  || c_lf ||
                            '    and t.column_name = c.column_name'
                        when 'ALL_TABLES' then
                            'sys.all_tab_comments c'                || c_lf ||
                            '    on  t.owner      = c.owner'        || c_lf ||
                            '    and t.table_name = c.table_name'
                        when 'ALL_VIEWS' then
                            'sys.all_tab_comments c'                || c_lf ||
                            '    on  t.owner     = c.owner'         || c_lf ||
                            '    and t.view_name = c.table_name'
                        when 'USER_TAB_COLUMNS' then
                            'sys.user_col_comments c'               || c_lf ||
                            '    on  t.table_name  = c.table_name'  || c_lf ||
                            '    and t.column_name = c.column_name'
                        when 'USER_TABLES' then
                            'sys.user_tab_comments c'               || c_lf ||
                            '    on t.table_name = c.table_name'
                        when 'USER_VIEWS' then
                            'sys.user_tab_comments c'               || c_lf ||
                            '    on t.view_name = c.table_name'
                    end || c_lf
                end ||
                case when p_owner = 'SYS' and p_table_name in (
                                                'ALL_TAB_COLUMNS',
                                                'USER_TAB_COLUMNS' ) then
                    '  left join ' ||
                    case p_table_name
                        when 'USER_TAB_COLUMNS' then
                            'sys.user_tab_identity_cols i'          || c_lf ||
                            '    on  t.table_name  = i.table_name'  || c_lf ||
                            '    and t.column_name = i.column_name'
                        when 'ALL_TAB_COLUMNS' then
                            'sys.all_tab_identity_cols i'           || c_lf ||
                            '    on  t.owner       = i.owner'       || c_lf ||
                            '    and t.table_name  = i.table_name'  || c_lf ||
                            '    and t.column_name = i.column_name'
                    end || c_lf
                end
                ;

            if p_debug then
                sys.dbms_output.put_line(l_code);
            end if;

            execute immediate(l_code);

            -- copy over table/view comments
            for i in ( select *
                         from sys.all_tab_comments
                        where owner      = p_owner
                          and table_name = p_table_name )
            loop
                execute immediate 'comment on materialized view ' || l_mview_name ||
                                  ' is ''' || replace(i.comments,'''', '''''') || '''';
            end loop;

            -- copy over column comments
            for i in ( select *
                         from sys.all_col_comments
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

            -- add indexes in case of SYS tables
            if p_owner = 'SYS' then
                case p_table_name
                    when 'ALL_TABLES'
                        then
                            create_index(l_mview_name, 'IDX1', 'OWNER,TABLE_NAME');
                    when 'ALL_TAB_COLUMNS'
                        then
                            create_index(l_mview_name, 'IDX1', 'OWNER,TABLE_NAME,COLUMN_NAME,COLUMN_ID');
                    when 'ALL_CONSTRAINTS'
                        then
                            create_index(l_mview_name, 'IDX1', 'OWNER,CONSTRAINT_NAME,STATUS');
                            create_index(l_mview_name, 'IDX2', 'OWNER,TABLE_NAME,STATUS');
                    when 'ALL_CONS_COLUMNS'
                        then
                            create_index(l_mview_name, 'IDX1', 'OWNER,CONSTRAINT_NAME');
                            create_index(l_mview_name, 'IDX2', 'OWNER,TABLE_NAME,COLUMN_NAME');
                    when 'ALL_INDEXES'
                        then
                            create_index(l_mview_name, 'IDX1', 'OWNER,INDEX_NAME');
                            create_index(l_mview_name, 'IDX2', 'OWNER,TABLE_NAME');
                    when 'ALL_IND_COLUMNS'
                        then
                            create_index(l_mview_name, 'IDX1', 'INDEX_OWNER,INDEX_NAME,COLUMN_NAME');
                    when 'ALL_OBJECTS'
                        then
                            create_index(l_mview_name, 'IDX1', 'OWNER,OBJECT_NAME,OBJECT_TYPE');
                    when 'ALL_DEPENDENCIES'
                        then
                            create_index(l_mview_name, 'IDX1', 'OWNER,NAME');
                            create_index(l_mview_name, 'IDX2', 'REFERENCED_OWNER,REFERENCED_NAME');
                    when 'ALL_VIEWS'
                        then
                            create_index(l_mview_name, 'IDX1', 'OWNER,VIEW_NAME');
                    when 'ALL_TRIGGERS'
                        then
                            create_index(l_mview_name, 'IDX1', 'OWNER,TRIGGER_NAME');
                            create_index(l_mview_name, 'IDX2', 'OWNER,TABLE_NAME');
                    when 'ALL_SYNONYMS'
                        then
                            create_index(l_mview_name, 'IDX1', 'OWNER,SYNONYM_NAME');
                            create_index(l_mview_name, 'IDX2', 'TABLE_OWNER,TABLE_NAME');
                    when 'USER_TAB_PRIVS'
                        then
                            create_index(l_mview_name, 'IDX1', 'OWNER,TABLE_NAME');
                    else
                        null;
                end case;
            end if;
        end if;

        sys.dbms_output.put_line (
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
      from sys.user_mviews
     where mview_name = p_mview_name;

    if l_count = 1 then
        l_sql := 'drop materialized view ' || p_mview_name;
        sys.dbms_output.put_line (
            '- ' || runtime(l_start) ||
            ' - materialized view dropped - ' || p_mview_name);
        execute immediate l_sql;
    else
        sys.dbms_output.put_line (
            '- ' || runtime(l_start) ||
            ' - materialized view does not exist - ' || p_mview_name);
    end if;

end drop_mview;

--------------------------------------------------------------------------------

procedure create_or_refresh_base_mviews
is
begin
    for i in 1..g_base_mviews.count loop
        create_or_refresh_mview( g_base_mviews(i), 'SYS' );
    end loop;
end create_or_refresh_base_mviews;

--------------------------------------------------------------------------------

procedure drop_base_mviews
is
begin
    for i in 1..g_base_mviews.count loop
        drop_mview( g_base_mviews(i) || '_MV' );
    end loop;
end drop_base_mviews;

--------------------------------------------------------------------------------

function all_base_mviews_exist return boolean
is
    l_user_mviews t_vc2_tab;
    type t_array is table of pls_integer index by varchar2(128);
    l_array t_array;
begin
    select mview_name
      bulk collect into l_user_mviews
      from sys.user_mviews;
    for i in 1..l_user_mviews.count loop
        l_array(l_user_mviews(i)) := null; -- the value does not matter
    end loop;
    for i in 1..g_base_mviews.count loop
        if not l_array.exists(g_base_mviews(i) || '_MV') then
            return false;
        end if;
    end loop;
    return true;
end all_base_mviews_exist;

--------------------------------------------------------------------------------

function last_refresh_base_mviews return date
is
    l_last_refresh date;
begin
    select min(last_refresh)
      into l_last_refresh
      from sys.user_mview_refresh_times
     where name in (
        select column_value || '_MV' from table (model.list_base_mviews) );
    return l_last_refresh;
end last_refresh_base_mviews;

--------------------------------------------------------------------------------

procedure create_index (
    p_table_name in varchar2,
    p_postfix    in varchar2,
    p_columns    in varchar2,
    p_unique     in boolean default false )
is
    l_ddl varchar2(32767);
begin
    l_ddl := 'create ' || case when p_unique then 'unique ' end ||
        'index ' || p_table_name || '_' || p_postfix || ' on ' ||
        p_table_name || ' (' || p_columns || ')';
    --sys.dbms_output.put_line ('- ' || l_ddl);
    execute immediate l_ddl;
end;

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
              from sys.user_tab_columns
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
              from sys.user_nested_table_cols
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
              from sys.user_constraints
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
              from sys.user_triggers
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
    l_return    varchar2(32767) := p_like;
    l_has_space boolean         := false;
begin
    -- process space
    if instr(l_return, ' ') > 0 then
        l_has_space := true;
        l_return    := regexp_replace(l_return, '\s+', '|');
    end if;

    -- process star
    l_return := replace(l_return, '*', '.*');

    -- process percent
    l_return := replace(l_return, '%', '.*');

    -- escape $
    l_return := replace(l_return, '$', '\$');

    -- process multiple like pattern
    if l_has_space then
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