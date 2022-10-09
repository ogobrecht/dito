create or replace package body model_joel is

--------------------------------------------------------------------------------

function get_table_query_apex (
    p_table_name             in varchar2,
    p_schema_name            in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
    p_max_cols_number        in integer default 20,
    p_max_cols_varchar       in integer default 20,
    p_max_cols_clob          in integer default  5,
    p_max_cols_date          in integer default  5,
    p_max_cols_timestamp     in integer default  5,
    p_max_cols_timestamp_tz  in integer default  5,
    p_max_cols_timestamp_ltz in integer default  5 )
    return varchar2
is
    v_return            varchar2(32767);
    v_column_expression varchar2(200);
    v_generic_column    varchar2(30);
    v_sep               varchar2(2) := ',' || chr(10);
    v_column_indent     varchar2(7) := '       ';
    v_table_exists      boolean     := false;
    v_count_n           pls_integer := 0;
    v_count_vc          pls_integer := 0;
    v_count_clob        pls_integer := 0;
    v_count_d           pls_integer := 0;
    v_count_ts          pls_integer := 0;
    v_count_tstz        pls_integer := 0;
    v_count_tsltz       pls_integer := 0;

    ----------------------------------------

    procedure process_table_columns
    is
        v_column_included boolean;
    begin
        for i in (
            select
                column_name,
                data_type
            from
                all_tab_columns_mv
            where
                owner = p_schema_name
                and table_name = p_table_name
            order by
                column_id )
        loop
            v_table_exists    := true;
            v_column_included := true;
            case
                when i.data_type in ('NUMBER', 'FLOAT') and v_count_n < p_max_cols_number then
                    v_count_n           := v_count_n + 1;
                    v_column_expression := i.column_name;
                    v_generic_column    := 'N' || lpad(to_char(v_count_n), 3, '0');

                when i.data_type in ('CHAR', 'VARCHAR2') and v_count_vc < p_max_cols_varchar then
                    v_count_vc          := v_count_vc + 1;
                    v_column_expression := i.column_name;
                    v_generic_column    := 'VC' || lpad(to_char(v_count_vc), 3, '0');

                when i.data_type = 'CLOB' and v_count_clob < p_max_cols_clob then
                    v_count_clob        := v_count_clob + 1;
                    v_column_expression := 'substr(' || i.column_name || ', 1, 4000)';
                    v_generic_column    := 'CLOB' || lpad(to_char(v_count_clob), 3, '0');

                when i.data_type = 'DATE' and v_count_d < p_max_cols_date then
                    v_count_d           := v_count_d + 1;
                    v_column_expression := i.column_name;
                    v_generic_column    := 'D' || lpad(to_char(v_count_d), 3, '0');

                when i.data_type like 'TIMESTAMP% WITH LOCAL TIME ZONE' and v_count_tsltz < p_max_cols_timestamp_ltz then
                    v_count_tsltz       := v_count_tsltz + 1;
                    v_column_expression := i.column_name;
                    v_generic_column    := 'TSLTZ' || lpad(to_char(v_count_tsltz), 3, '0');

                when i.data_type like 'TIMESTAMP% WITH TIME ZONE' and v_count_tstz < p_max_cols_timestamp_tz then
                    v_count_tstz        := v_count_tstz + 1;
                    v_column_expression := i.column_name;
                    v_generic_column    := 'TSTZ' || lpad(to_char(v_count_tstz), 3, '0');

                when i.data_type like 'TIMESTAMP%' and v_count_ts < p_max_cols_timestamp then
                    v_count_ts          := v_count_ts + 1;
                    v_column_expression := i.column_name;
                    v_generic_column    := 'TS' || lpad(to_char(v_count_ts), 3, '0');

                else
                    v_column_included := false;
            end case;

            if v_column_included then
                v_return := v_return
                    || v_column_indent || v_column_expression
                    || ' as ' || v_generic_column || v_sep;
            end if;

            apex_util.set_session_state (
                p_name  => v_generic_column,
                p_value => initcap(replace(i.column_name, '_', ' ')) );
        end loop;
    end process_table_columns;

    ----------------------------------------

    procedure fill_up_generic_columns (
        p_type in varchar2 )
    is
        v_count     pls_integer;
        v_max_count pls_integer;
    begin
        v_count :=
            case p_type
                when 'N'     then v_count_n
                when 'VC'    then v_count_vc
                when 'CLOB'  then v_count_clob
                when 'D'     then v_count_d
                when 'TS'    then v_count_ts
                when 'TSTZ'  then v_count_tstz
                when 'TSLTZ' then v_count_tsltz
            end + 1;

        v_max_count :=
            case p_type
                when 'N'     then p_max_cols_number
                when 'VC'    then p_max_cols_varchar
                when 'CLOB'  then p_max_cols_clob
                when 'D'     then p_max_cols_date
                when 'TS'    then p_max_cols_timestamp
                when 'TSTZ'  then p_max_cols_timestamp_tz
                when 'TSLTZ' then p_max_cols_timestamp_ltz
            end;

        for i in v_count .. v_max_count loop
            v_generic_column := p_type || lpad(to_char(i), 3, '0');

            v_return         := v_return || v_column_indent ||
                                'null as ' || v_generic_column || v_sep;

            apex_util.set_session_state (
                p_name  => v_generic_column,
                p_value => null );
        end loop;
    end fill_up_generic_columns;

    ----------------------------------------

begin
    process_table_columns;

    fill_up_generic_columns(p_type => 'N'    );
    fill_up_generic_columns(p_type => 'D'    );
    fill_up_generic_columns(p_type => 'TS'   );
    fill_up_generic_columns(p_type => 'TSTZ' );
    fill_up_generic_columns(p_type => 'TSLTZ');
    fill_up_generic_columns(p_type => 'VC'   );
    fill_up_generic_columns(p_type => 'CLOB' );

    v_return :=    'select ' || rtrim( ltrim(v_return), v_sep ) || chr(10)
                || '  from ' || case when v_table_exists
                                    then p_schema_name || '.' || p_table_name
                                    else 'dual'
                                end;

    return v_return;
end get_table_query_apex;

--------------------------------------------------------------------------------

procedure create_application_items (
    p_app_id                 in integer,
    p_max_cols_number        in integer default 20,
    p_max_cols_varchar       in integer default 20,
    p_max_cols_clob          in integer default  5,
    p_max_cols_date          in integer default  5,
    p_max_cols_timestamp     in integer default  5,
    p_max_cols_timestamp_tz  in integer default  5,
    p_max_cols_timestamp_ltz in integer default  5 )
is
    v_app_items wwv_flow_global.vc_map;

    ----------------------------------------

    procedure create_items (
        p_type in varchar2 )
    is
        v_generic_column varchar2(30);
        v_count          pls_integer;
        v_max_count      pls_integer;
        v_count_n        pls_integer := 0;
        v_count_vc       pls_integer := 0;
        v_count_clob     pls_integer := 0;
        v_count_d        pls_integer := 0;
        v_count_ts       pls_integer := 0;
        v_count_tstz     pls_integer := 0;
        v_count_tsltz    pls_integer := 0;
    begin
        v_count :=
            case p_type
                when 'N'     then v_count_n
                when 'VC'    then v_count_vc
                when 'CLOB'  then v_count_clob
                when 'D'     then v_count_d
                when 'TS'    then v_count_ts
                when 'TSTZ'  then v_count_tstz
                when 'TSLTZ' then v_count_tsltz
            end + 1;

        v_max_count :=
            case p_type
                when 'N'     then p_max_cols_number
                when 'VC'    then p_max_cols_varchar
                when 'CLOB'  then p_max_cols_clob
                when 'D'     then p_max_cols_date
                when 'TS'    then p_max_cols_timestamp
                when 'TSTZ'  then p_max_cols_timestamp_tz
                when 'TSLTZ' then p_max_cols_timestamp_ltz
            end;

        for i in v_count .. v_max_count loop
            v_generic_column := p_type || lpad(to_char(i), 3, '0');

            --FIXME: create page item

        end loop;
    end create_items;

    ----------------------------------------

begin
    -- prepare map
    for i in (
        select
            item_name
        from
            apex_application_items
        where
            application_id = p_app_id )
    loop
        v_app_items ( i.item_name ) := null; -- we need only the key
    end loop;

    -- create app items as needed

    --FIXME: call subprocedure

end create_application_items;

--------------------------------------------------------------------------------

end model_joel;
/