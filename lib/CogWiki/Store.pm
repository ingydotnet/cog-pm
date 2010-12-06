package CogWiki::Store;
use Mouse;
use Git::Wrapper;
use Convert::Base32 ();

has root_dir => (is => 'ro', default => 'cog');

srand();

my $cog_node_dir = 'cog/node';

sub BUILD {
    my $self = shift;
    my $root = $self->root_dir;
}

sub new_cog_id {
    while (1) {
        # Upper cased base32 128bit random number.
        my $id = uc Convert::Base32::encode_base32(
            join "", map { pack "S", int(rand(65536)) } 1..8
        ); 
        next unless $id =~ /^((?:[A-Z][2-7]|[2-7][A-Z])..)(.*)/;
        next if -e "$cog_node_dir/$1";
        return "$1-$2";
    }
}

1;
