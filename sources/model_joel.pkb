create or replace package body model_joel is

--------------------------------------------------------------------------------

function get_table_query (
    p_table_name             in varchar2,
    p_schema_name            in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
    p_max_cols_varchar       in integer default 20,
    p_max_cols_number        in integer default 20,
    p_max_cols_date          in integer default 20,
    p_max_cols_timestamp     in integer default 20,
    p_max_cols_timestamp_tz  in integer default 20,
    p_max_cols_timestamp_ltz in integer default 20 )
    return varchar2
is
    v_return         varchar2(32767);
    v_generic_column varchar2(30);
    v_sep            varchar2(2) := ',' || chr(10);
    v_column_indent  varchar2(7) := '       ';
    v_count_vc       number      := 0;
    v_count_n        number      := 0;
    v_count_d        number      := 0;
    v_count_ts       number      := 0;
    v_count_tstz     number      := 0;
    v_count_tsltz    number      := 0;

    ----------------------------------------

    procedure process_table_columns is
    begin
        for i in ( select column_name,
                          data_type
                     from all_tab_columns_mv
                    where owner      = p_schema_name
                      and table_name = p_table_name
                    order by column_id )
        loop
            case
                when i.data_type in ('CHAR', 'VARCHAR2') then
                    v_count_vc := v_count_vc + 1;
                    v_generic_column := 'VC' || lpad(to_char(v_count_vc), 3, '0');

                when i.data_type in ('NUMBER', 'FLOAT') then
                    v_count_n := v_count_n + 1;
                    v_generic_column := 'N' || lpad(to_char(v_count_n), 3, '0');

                when i.data_type = 'DATE' then
                    v_count_d := v_count_d + 1;
                    v_generic_column := 'D' || lpad(to_char(v_count_d), 3, '0');

                when i.data_type like 'TIMESTAMP% WITH LOCAL TIME ZONE' then
                    v_count_tsltz := v_count_tsltz + 1;
                    v_generic_column := 'TSLTZ' || lpad(to_char(v_count_tsltz), 3, '0');

                when i.data_type like 'TIMESTAMP% WITH TIME ZONE' then
                    v_count_tstz := v_count_tstz + 1;
                    v_generic_column := 'TSTZ' || lpad(to_char(v_count_tstz), 3, '0');

                when i.data_type like 'TIMESTAMP%' then
                    v_count_ts := v_count_ts + 1;
                    v_generic_column := 'TS' || lpad(to_char(v_count_ts), 3, '0');

                else null;
            end case;

            v_return := v_return || v_column_indent || i.column_name ||
                        ' as ' || v_generic_column || v_sep;

            apex_util.set_session_state (
                p_name  => v_generic_column,
                p_value => initcap(replace(i.column_name, '_', ' ')) );
        end loop;
    end process_table_columns;

    ----------------------------------------

    procedure fill_up_generic_columns (
        p_type in varchar2 )
    is
        v_count pls_integer := 0;
    begin
        v_count := case p_type
                        when 'VC'    then v_count_vc
                        when 'N'     then v_count_n
                        when 'D'     then v_count_d
                        when 'TS'    then v_count_ts
                        when 'TSTZ'  then v_count_tstz
                        when 'TSLTZ' then v_count_tsltz
                   end + 1;

        for i in v_count .. p_max_cols_varchar loop
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

    fill_up_generic_columns(p_type => 'VC'   );
    fill_up_generic_columns(p_type => 'N'    );
    fill_up_generic_columns(p_type => 'D'    );
    fill_up_generic_columns(p_type => 'TS'   );
    fill_up_generic_columns(p_type => 'TSTZ' );
    fill_up_generic_columns(p_type => 'TSLTZ');

    v_return := 'select ' || rtrim( ltrim(v_return), v_sep ) || chr(10) ||
                '  from ' || p_schema_name || '.' || p_table_name;

    return v_return;
end get_table_query;

--------------------------------------------------------------------------------

end model_joel;
/