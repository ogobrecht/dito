declare
    l_apex_installed     varchar2(5) := 'FALSE'; -- Do not change (is set dynamically).
    l_utils_public       varchar2(5) := 'FALSE'; -- Make utilities public available (for testing or other usages).
    l_native_compilation boolean     := false;   -- Set this to true at your own risk (in the Oracle cloud you will get likely an "insufficient privileges" error)
    l_count pls_integer;
begin

    execute immediate 'alter session set plsql_warnings = ''enable:all,disable:5004,disable:6005,disable:6006,disable:6009,disable:6010,disable:6027,disable:7207''';
    execute immediate 'alter session set plscope_settings = ''identifiers:all''';
    execute immediate 'alter session set plsql_optimize_level = 3';

    if l_native_compilation then
        execute immediate 'alter session set plsql_code_type=''native''';
    end if;

    select count(*) into l_count from all_objects where object_type = 'SYNONYM' and object_name = 'APEX_EXPORT';
    l_apex_installed := case when l_count = 0 then 'FALSE' else 'TRUE' end;

    execute immediate 'alter session set plsql_ccflags = '''
        || 'APEX_INSTALLED:' || l_apex_installed || ','
        || 'UTILS_PUBLIC:'   || l_utils_public   || '''';

    -- select * from all_plsql_object_settings where name = 'MODEL';
end;
/
