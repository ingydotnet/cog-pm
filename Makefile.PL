use inc::Module::Install;

all_from 'lib/Cog.pm';
readme_from;
manifest_skip;
version_check;
ack_xxx;
repository 'git://github.com/ingydotnet/cog-pm.git';

test_requires 'Capture::Tiny';

requires 'Class::Throwable';
requires 'Convert::Base32::Crockford';
requires 'File::ShareDir';
requires 'IO::All';
requires 'IPC::Run';
requires 'Jemplate';
requires 'JSON';
requires 'Mouse';
requires 'Plack';
requires 'Plack::Middleware::Cache';
requires 'Plack::Middleware::ETag';
requires 'Plack::Middleware::ProxyMap';
requires 'Template::Toolkit::Simple';
requires 'YAML::XS';

install_script 'bin/cog';

install_share;

WriteAll;
