package Cog::Store;
use Mouse;
use IO::All;
use Git::Wrapper;
use Convert::Base32 ();

# use XXX;

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

sub index_name {
    my $self = shift;
    my $root = $self->root;
    my ($name, $id) = @_;
    $name = lc($name);
    $name =~ s/[^a-z0-9]+/_/g;
    $name =~ s/^_*(.*?)_*$/$1/;
    $name ||= '_';

    io->file("$root/index/name/$name/$id")->assert->touch();
    return $name;
}

sub index_tag {
    my $self = shift;
    my $root = $self->root;
    my ($tag, $id) = @_;
    io->file("$root/index/tag/$tag/$id")->assert->touch();
}

sub all_tags {
    my $self = shift;
    my $tag_root = $self->root . '/index/tag/';
    return [] unless -e $tag_root;
    return [map $_->filename, io($tag_root)->all];
}

sub indexed_tag {
    my $self = shift;
    my $tag = shift;
    my $root = $self->root;
    return [map $_->filename, io("$root/index/tag/$tag")->all];
}

sub delete_tag_index {
    my $self = shift;
    my $root = $self->root;
    io->dir("$root/index/tag")->rmtree;
}

1;
