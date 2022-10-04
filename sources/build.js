const fs = require('fs');
console.log('ORACLE DICTIONARY TOOLS: BUILD SQL SCRIPTS');

console.log('- build file install/core.sql');
fs.writeFileSync('install/core.sql',
    '--DO NOT CHANGE THIS FILE - IT IS GENERATED WITH THE BUILD SCRIPT build.js\n' +
    fs.readFileSync('sources/install_template_dito.sql', 'utf8')
        .replace('@set_ccflags.sql', function () { return fs.readFileSync('sources/set_ccflags.sql', 'utf8') })
        .replace('@dito.pks', function () { return fs.readFileSync('sources/dito.pks', 'utf8') })
        .replace('@dito.pkb', function () { return fs.readFileSync('sources/dito.pkb', 'utf8') })
        .replace('@show_errors_dito.sql', function () { return fs.readFileSync('sources/show_errors_dito.sql', 'utf8') })
        .replace('@log_installed_version.sql', function () { return fs.readFileSync('sources/log_installed_version.sql', 'utf8') })
    /*
    Without the anonymous function call to fs.readFileSync we get wrong results, if
    we have a dollar signs in our package body text - the last answer explains it:
    https://stackoverflow.com/questions/9423722/string-replace-weird-behavior-when-using-dollar-sign-as-replacement
    */
);

console.log('- build file install/apex_extension.sql');
fs.writeFileSync('install/apex_extension.sql',
    '--DO NOT CHANGE THIS FILE - IT IS GENERATED WITH THE BUILD SCRIPT build.js\n' +
    fs.readFileSync('sources/install_template_dito_apex.sql', 'utf8')
        .replace('@set_ccflags.sql', function () { return fs.readFileSync('sources/set_ccflags.sql', 'utf8') })
        .replace('@dito_apex.pks', function () { return fs.readFileSync('sources/dito_apex.pks', 'utf8') })
        .replace('@dito_apex.pkb', function () { return fs.readFileSync('sources/dito_apex.pkb', 'utf8') })
        .replace('@show_errors_dito_apex.sql', function () { return fs.readFileSync('sources/show_errors_dito_apex.sql', 'utf8') })
        .replace('@log_installed_version.sql', function () { return fs.readFileSync('sources/log_installed_version.sql', 'utf8') })
    /*
    Without the anonymous function call to fs.readFileSync we get wrong results, if
    we have a dollar signs in our package body text - the last answer explains it:
    https://stackoverflow.com/questions/9423722/string-replace-weird-behavior-when-using-dollar-sign-as-replacement
    */
);
