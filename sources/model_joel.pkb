create or replace package body model_joel is

--------------------------------------------------------------------------------

function get_table_query_apex (
    p_table_name             in varchar2           ,
    p_schema_name            in varchar2 default sys_context('USERENV', 'CURRENT_USER'),
    p_max_cols_number        in integer default 20 ,
    p_max_cols_date          in integer default  5 ,
    p_max_cols_timestamp_ltz in integer default  5 ,
    p_max_cols_timestamp_tz  in integer default  5 ,
    p_max_cols_timestamp     in integer default  5 ,
    p_max_cols_varchar       in integer default 20 ,
    p_max_cols_clob          in integer default  5 )
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

                when i.data_type in ('CHAR', 'VARCHAR2') and v_count_vc < p_max_cols_varchar then
                    v_count_vc          := v_count_vc + 1;
                    v_column_expression := i.column_name;
                    v_generic_column    := 'VC' || lpad(to_char(v_count_vc), 3, '0');

                when i.data_type = 'CLOB' and v_count_clob < p_max_cols_clob then
                    v_count_clob        := v_count_clob + 1;
                    v_column_expression := 'substr(' || i.column_name || ', 1, 4000)';
                    v_generic_column    := 'CLOB' || lpad(to_char(v_count_clob), 3, '0');

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
        v_count    pls_integer;
        v_max_cols pls_integer;
    begin
        v_count :=
            case p_type
                when 'N'     then v_count_n
                when 'D'     then v_count_d
                when 'TSLTZ' then v_count_tsltz
                when 'TSTZ'  then v_count_tstz
                when 'TS'    then v_count_ts
                when 'VC'    then v_count_vc
                when 'CLOB'  then v_count_clob
            end + 1;

        v_max_cols :=
            case p_type
                when 'N'     then p_max_cols_number
                when 'D'     then p_max_cols_date
                when 'TSLTZ' then p_max_cols_timestamp_ltz
                when 'TSTZ'  then p_max_cols_timestamp_tz
                when 'TS'    then p_max_cols_timestamp
                when 'VC'    then p_max_cols_varchar
                when 'CLOB'  then p_max_cols_clob
            end;

        for i in v_count .. v_max_cols
        loop
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

    fill_up_generic_columns ( p_type => 'N'     );
    fill_up_generic_columns ( p_type => 'D'     );
    fill_up_generic_columns ( p_type => 'TSLTZ' );
    fill_up_generic_columns ( p_type => 'TSTZ'  );
    fill_up_generic_columns ( p_type => 'TS'    );
    fill_up_generic_columns ( p_type => 'VC'    );
    fill_up_generic_columns ( p_type => 'CLOB'  );

    v_return :=    'select ' || rtrim( ltrim(v_return), v_sep ) || chr(10)
                || '  from ' || case when v_table_exists
                                    then p_schema_name || '.' || p_table_name
                                    else 'dual'
                                end;

    return v_return;
end get_table_query_apex;

--------------------------------------------------------------------------------

procedure create_application_items (
    p_app_id                 in integer            ,
    p_max_cols_number        in integer default 20 ,
    p_max_cols_date          in integer default  5 ,
    p_max_cols_timestamp_ltz in integer default  5 ,
    p_max_cols_timestamp_tz  in integer default  5 ,
    p_max_cols_timestamp     in integer default  5 ,
    p_max_cols_varchar       in integer default 20 ,
    p_max_cols_clob          in integer default  5 )
is
    v_app_items wwv_flow_global.vc_map;

    ----------------------------------------

    procedure create_items (
        p_type in varchar2 )
    is
        v_generic_column varchar2(30);
        v_max_cols       pls_integer;
        v_count_n        pls_integer := 0;
        v_count_vc       pls_integer := 0;
        v_count_clob     pls_integer := 0;
        v_count_d        pls_integer := 0;
        v_count_ts       pls_integer := 0;
        v_count_tstz     pls_integer := 0;
        v_count_tsltz    pls_integer := 0;
    begin
        v_max_cols :=
            case p_type
                when 'N'     then p_max_cols_number
                when 'D'     then p_max_cols_date
                when 'TSLTZ' then p_max_cols_timestamp_ltz
                when 'TSTZ'  then p_max_cols_timestamp_tz
                when 'TS'    then p_max_cols_timestamp
                when 'VC'    then p_max_cols_varchar
                when 'CLOB'  then p_max_cols_clob
            end;

        for i in 1 .. v_max_cols
        loop
            v_generic_column := p_type || lpad(to_char(i), 3, '0');

            if not v_app_items.exists(v_generic_column) then
                wwv_flow_imp_shared.create_flow_item (
                    p_flow_id          => p_app_id,
                    p_id               => wwv_flow_id.next_val,
                    p_name             => v_generic_column,
                    p_protection_level => 'I' );
            end if;
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
    create_items( p_type => 'N'     );
    create_items( p_type => 'D'     );
    create_items( p_type => 'TSLTZ' );
    create_items( p_type => 'TSTZ'  );
    create_items( p_type => 'TS'    );
    create_items( p_type => 'VC'    );
    create_items( p_type => 'CLOB'  );

end create_application_items;

--------------------------------------------------------------------------------

procedure create_interactive_report (
    p_app_id                 in integer            ,
    p_page_id                in integer            ,
    p_max_cols_number        in integer default 20 ,
    p_max_cols_date          in integer default  5 ,
    p_max_cols_timestamp_ltz in integer default  5 ,
    p_max_cols_timestamp_tz  in integer default  5 ,
    p_max_cols_timestamp     in integer default  5 ,
    p_max_cols_varchar       in integer default 20 ,
    p_max_cols_clob          in integer default  5 )
is
    v_display_order number := 10;

    ----------------------------------------

    function get_template_id (
        p_type  in varchar2,
        p_name  in varchar2,
        p_theme in number default 42)
        return number
    is
        v_return number;
    begin
        select
            template_id
        into
            v_return
        from
            apex_application_templates
        where
            application_id = p_app_id
            and theme_number = 42
            and template_type = p_type
            and template_name = p_name;
    return v_return;
    exception
        when no_data_found then
            return null;
    end get_template_id;

    ----------------------------------------

    procedure create_report
    is
        v_temp_id number;
    begin
        wwv_flow_imp_page.create_page_plug (
            p_flow_id                     => p_app_id,
            p_page_id                     => p_page_id,
            p_id                          => wwv_flow_id.next_val,
            p_plug_name                   => 'Generic Table Data Report',
            p_region_template_options     => '#DEFAULT#',
            p_component_template_options  => '#DEFAULT#',
            p_plug_template               => get_template_id('Region', 'Interactive Report'),
            p_plug_display_sequence       => 10,
            p_include_in_reg_disp_sel_yn  => 'Y',
            p_query_type                  => 'FUNC_BODY_RETURNING_SQL',
            p_function_body_language      => 'PLSQL',
            p_plug_source                 => 'return model_joel.get_table_query_apex(:your_table_item_here)',
            p_plug_source_type            => 'NATIVE_IR',
            p_plug_query_options          => 'DERIVED_REPORT_COLUMNS',
            p_prn_content_disposition     => 'ATTACHMENT',
            p_prn_units                   => 'INCHES',
            p_prn_paper_size              => 'LETTER',
            p_prn_width                   => 11,
            p_prn_height                  => 8.5,
            p_prn_orientation             => 'HORIZONTAL',
            p_prn_page_header             => 'Generic Table Data Report',
            p_prn_page_header_font_color  => '#000000',
            p_prn_page_header_font_family => 'Helvetica',
            p_prn_page_header_font_weight => 'normal',
            p_prn_page_header_font_size   => '12',
            p_prn_page_footer_font_color  => '#000000',
            p_prn_page_footer_font_family => 'Helvetica',
            p_prn_page_footer_font_weight => 'normal',
            p_prn_page_footer_font_size   => '12',
            p_prn_header_bg_color         => '#EEEEEE',
            p_prn_header_font_color       => '#000000',
            p_prn_header_font_family      => 'Helvetica',
            p_prn_header_font_weight      => 'bold',
            p_prn_header_font_size        => '10',
            p_prn_body_bg_color           => '#FFFFFF',
            p_prn_body_font_color         => '#000000',
            p_prn_body_font_family        => 'Helvetica',
            p_prn_body_font_weight        => 'normal',
            p_prn_body_font_size          => '10',
            p_prn_border_width            => .5,
            p_prn_page_header_alignment   => 'CENTER',
            p_prn_page_footer_alignment   => 'CENTER',
            p_prn_border_color            => '#666666' );

        v_temp_id := wwv_flow_id.next_val;

        wwv_flow_imp_page.create_worksheet (
            p_flow_id                => p_app_id,
            p_page_id                => p_page_id,
            p_id                     => v_temp_id,
            p_max_row_count          => '1000000',
            p_pagination_type        => 'ROWS_X_TO_Y',
            p_pagination_display_pos => 'BOTTOM_RIGHT',
            p_show_display_row_count => 'Y',
            p_report_list_mode       => 'TABS',
            p_lazy_loading           => false,
            p_show_detail_link       => 'N',
            p_show_notify            => 'Y',
            p_download_formats       => 'CSV:HTML:XLSX:PDF',
            p_enable_mail_download   => 'Y',
            p_owner                  => apex_application.g_user,
            p_internal_uid           => v_temp_id );
    end create_report;

    ----------------------------------------

    procedure create_report_columns (
        p_type in varchar2 )
    is
        v_generic_column varchar2(30);
        v_max_cols       pls_integer;
        v_count_n        pls_integer := 0;
        v_count_vc       pls_integer := 0;
        v_count_clob     pls_integer := 0;
        v_count_d        pls_integer := 0;
        v_count_ts       pls_integer := 0;
        v_count_tstz     pls_integer := 0;
        v_count_tsltz    pls_integer := 0;
    begin
        v_max_cols :=
            case p_type
                when 'N'     then p_max_cols_number
                when 'D'     then p_max_cols_date
                when 'TSLTZ' then p_max_cols_timestamp_ltz
                when 'TSTZ'  then p_max_cols_timestamp_tz
                when 'TS'    then p_max_cols_timestamp
                when 'VC'    then p_max_cols_varchar
                when 'CLOB'  then p_max_cols_clob
            end;

        for i in 1 .. v_max_cols
        loop
            v_generic_column := p_type || lpad(to_char(i), 3, '0');

            wwv_flow_imp_page.create_worksheet_column (
                p_id                => wwv_flow_id.next_val,
                p_db_column_name    => v_generic_column,
                p_display_order     => v_display_order,
                p_column_identifier => v_generic_column,
                p_column_label      => '&'||v_generic_column||'.',
                p_column_type       => 'STRING',
                p_use_as_row_header => 'N' );

            v_display_order := v_display_order + 10;
        end loop;
    end create_report_columns;

    ----------------------------------------

begin

    create_report;
    create_report_columns ( p_type => 'N'     );
    create_report_columns ( p_type => 'D'     );
    create_report_columns ( p_type => 'TSLTZ' );
    create_report_columns ( p_type => 'TSTZ'  );
    create_report_columns ( p_type => 'TS'    );
    create_report_columns ( p_type => 'VC'    );
    create_report_columns ( p_type => 'CLOB'  );

end create_interactive_report;

--------------------------------------------------------------------------------

end model_joel;
/