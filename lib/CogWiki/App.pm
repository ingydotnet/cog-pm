package CogWiki::App;
use Mouse;
use Git::Wrapper;
use YAML::XS;
use Try::Tiny;
use Class::Throwable qw(Error);
use CogWiki::Config;
use IO::All;
use XXX;

has config => (
    is => 'ro',
    builder => sub {CogWiki::Config->new()},
);

sub handle_init {
    my $self = shift;
    throw Error "Can't init. Already is a cogwiki."
        if $self->config->is_wiki;
}

sub _config_build {
    return CogWiki::Config->new();
}

1;
