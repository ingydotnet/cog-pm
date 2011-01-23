package Cog::Base;
use Mouse;

use Carp;

my $config_object;

sub set_global_config_singleton_object {
    $config_object ||= $_[1];
}

sub config {
    Carp::confess("The config method has no setter") if @_ > 1;
    return $config_object;
}

1;
