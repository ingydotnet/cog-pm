package CogWiki::Store;
use Mouse;
use IO::All;
use Git::Wrapper;
use Convert::Base32 ();

use XXX;

has root => (is => 'ro', default => 'cog');

srand();

sub exists {
    my $self = shift;
    return -e $self->root;
}

sub create {
    my $self = shift;
    my $root = $self->root;
    io->dir($root)->assert->mkdir();
    mkdir "$root/node" or die;
    mkdir "$root/index" or die;
}

sub new_cog_id {
    my $self = shift;
    my $path = $self->root . '/node';
    my ($full, $short);
    while (1) {
        # Upper cased base32 128bit random number.
        my $id = uc Convert::Base32::encode_base32(
            join "", map { pack "S", int(rand(65536)) } 1..8
        ); 
        next unless $id =~ /^((?:[A-Z][2-7]|[2-7][A-Z])..)(.*)/;
        $short = $1;
        $full = "$1-$2";
        next if -e "$path/$short";
        last;
    }
    io("$path/$short")->touch();
    return $full;
}

1;
