use inc::Module::Install;

all_from 'lib/Cog.pm';
readme_from;
manifest_skip;
version_check;
ack_xxx;
repository 'git://github.com/ingydotnet/cog-pm.git';

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
requires 'Jemplate';

install_script 'bin/cog';

install_share;

WriteAll;
