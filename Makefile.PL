use inc::Module::Install;

all_from 'lib/CogWiki.pm';
readme_from;
manifest_skip;
version_check;
ack_xxx;
repository 'git://github.com/ingydotnet/cogwiki.git';

requires 'Mouse';
requires 'Try::Tiny';
requires 'Class::Throwable';

install_script 'bin/cogwiki';

clean_files 't/output/';

WriteAll;
