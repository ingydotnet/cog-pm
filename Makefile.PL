use inc::Module::Install;

all_from 'lib/CogWiki.pm';
readme_from;
manifest_skip;
version_check;
ack_xxx;
repository 'git://github.com/ingydotnet/cogwiki-pm.git';

requires 'Plack';
requires 'Mouse';
requires 'YAML::XS';
requires 'IO::All';
requires 'Try::Tiny';
requires 'Class::Throwable';
requires 'Time::Duration';
requires 'Git::Wrapper';
requires 'Convert::Base32';
requires 'Template::Toolkit::Simple';
requires 'IPC::Run';

install_script 'bin/cogwiki';

install_share;

WriteAll;
