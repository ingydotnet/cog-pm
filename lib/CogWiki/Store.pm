package CogWiki::Store;
use Mouse;
use Git::Wrapper;

has root_dir => (is => 'ro', default => 'cog');

sub BUILD {
    my $self = shift;
    my $root = $self->root_dir;
}

1;
