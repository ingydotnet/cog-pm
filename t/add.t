use Test::More tests => 29;
use t::Tests;

my $PATH = 't/cog1';

rmpath $PATH;
mkpath $PATH;
cd $PATH;
run_pass "$PERL $CWD/bin/cog init -a Cog::App::Test";
run_pass "$PERL $CWD/bin/cog new test_node";
cd;
rmpath $PATH;
