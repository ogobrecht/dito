const fs = require('fs');
console.log('ORACLE DATA MODEL UTILITIES: BUILD SQL SCRIPTS');
console.log('- build file install.sql');
fs.writeFileSync('model_install.sql',
    '--DO NOT CHANGE THIS FILE - IT IS GENERATED WITH THE BUILD SCRIPT build.js\n' +
    fs.readFileSync('src/model_install.sql', 'utf8')
        .replace('@MODEL.pks', function () { return fs.readFileSync('src/MODEL.pks', 'utf8') })
        .replace('@MODEL.pkb', function () { return fs.readFileSync('src/MODEL.pkb', 'utf8') })
    /*
    Without the anonymous function call to fs.readFileSync we get wrong results, if
    we have a dollar signs in our package body text - the last answer explains it:
    https://stackoverflow.com/questions/9423722/string-replace-weird-behavior-when-using-dollar-sign-as-replacement
    */
);

console.log('- copy file uninstall.sql');
fs.copyFileSync(
    'src/model_uninstall.sql',
    'model_uninstall.sql'
);
