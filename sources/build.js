const fs = require('fs');
console.log('ORACLE DICTIONARY TOOLS: BUILD SQL SCRIPTS');
console.log('- build file install/create_database_objects.sql');
fs.writeFileSync('install/create_database_objects.sql',
    '--DO NOT CHANGE THIS FILE - IT IS GENERATED WITH THE BUILD SCRIPT build.js\n' +
    fs.readFileSync('sources/install_template.sql', 'utf8')
        .replace('@set_ccflags.sql', function () { return fs.readFileSync('sources/set_ccflags.sql', 'utf8') })
        .replace('@DITO.pks', function () { return fs.readFileSync('sources/DITO.pks', 'utf8') })
        .replace('@DITO.pkb', function () { return fs.readFileSync('sources/DITO.pkb', 'utf8') })
        .replace('@show_errors.sql', function () { return fs.readFileSync('sources/show_errors.sql', 'utf8') })
        .replace('@log_installed_version.sql', function () { return fs.readFileSync('sources/log_installed_version.sql', 'utf8') })
    /*
    Without the anonymous function call to fs.readFileSync we get wrong results, if
    we have a dollar signs in our package body text - the last answer explains it:
    https://stackoverflow.com/questions/9423722/string-replace-weird-behavior-when-using-dollar-sign-as-replacement
    */
);
