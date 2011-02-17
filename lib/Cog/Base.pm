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
sub runner { $runner || ($maker = $config->runner) }
sub store { $store || ($maker = $config->store) }
sub webapp { $webapp || ($maker = $config->maker) }

1;
