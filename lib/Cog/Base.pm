package Cog::Base;
use Mouse;

my $config;
my $maker;
my $runner;
my $store;
my $webapp;

sub initialize { $config ||= $_[1] }

sub config { $config }
sub maker { $maker || ($maker = $config->maker) }
sub runner { $runner || ($runner = $config->runner) }
sub store { $store || ($store = $config->store) }
sub webapp { $webapp || ($webapp = $config->webapp) }

1;
