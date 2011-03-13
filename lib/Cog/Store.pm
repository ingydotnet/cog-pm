# TODO:
package Cog::Store;
use Mouse;
extends 'Cog::Base';

use Cog::Node;
use Cog::Node::Schema;
use IO::All;
use Git::Wrapper;
use Convert::Base32::Crockford ();

use XXX;

has root => (is => 'ro', default => 'cog');
has schema_map => (is => 'ro', default => sub {+{}});
use constant schemata => [
    'Cog::Node::Schema',
];

srand();

sub BUILD {
    my $self = shift;
    $self->schema_map->{CogNode} = Cog::Node::Schema->new();
    for my $class (@{$self->schemata}) {
        my $schema = $class->new;
        my $type = $schema->type;
        $self->schema_map->{$type} = $schema;
    }
    return $self;
};

sub connect { die '...'; }
sub exists { die '...'; }
sub init { die '...'; }
sub id_used { die '...'; }

# 2 - 352
# 3 - 15840
# 4 - 571648
# 5 - 19113600
# 6 - 615357952
# 7 - 19373544960
# 8 - 601207349248
sub new_cog_id {
    my $self = shift;
    my ($full, $short);
    while (1) {
        # Base32 125bit random number.
        my $full = uc Convert::Base32::Crockford::encode_base32(
            join "", map { pack "S", int(rand(65536)) } 1..8
        ); 
        chop $full;
        $full =~ s/(....)(.*)/$1-$2/ or die;
        $short = $1;
        next unless
            ($short =~/[2-9]/ and $short =~ /[A-Z]/ and $short !~ /[01]/);
        return $full
            unless $self->id_used($short, $full);
    }
}

sub import_files {
    my $self = shift;
    my $files = shift;
    for my $path (@$files) {
        my $node = $self->content->node_from_reference($path);
        $self->put($node, $path);
    }
}

sub reserve_keys {
    my $self = shift;
    my $files = shift;
    for my $path (@$files) {
        my $node = $self->content->node_from_reference($path);
        $self->id_used($node->Short, $node->Id . " archived");
    }
}

# sub index_name {
#     my $self = shift;
#     my $root = $self->root;
#     my ($name, $id) = @_;
#     $name = lc($name);
#     $name =~ s/[^a-z0-9]+/_/g;
#     $name =~ s/^_*(.*?)_*$/$1/;
#     $name ||= '_';
# 
#     io->file("$root/index/name/$name/$id")->assert->touch();
#     return $name;
# }
# 
# sub index_tag {
#     my $self = shift;
#     my $root = $self->root;
#     my ($tag, $id) = @_;
#     io->file("$root/index/tag/$tag/$id")->assert->touch();
# }
# 
# sub all_tags {
#     my $self = shift;
#     my $tag_root = $self->root . '/index/tag/';
#     return [] unless -e $tag_root;
#     return [map $_->filename, io($tag_root)->all];
# }
# 
# sub indexed_tag {
#     my $self = shift;
#     my $tag = shift;
#     my $root = $self->root;
#     return [map $_->filename, io("$root/index/tag/$tag")->all];
# }
# 
# sub delete_tag_index {
#     my $self = shift;
#     my $root = $self->root;
#     io->dir("$root/index/tag")->rmtree;
# }

1;

=head1 NAME

Cog::Store - Storage object base class for Cog App.

=head1 API

connect(root) -> $store - Connect to a store. Return store object.

init(root) -> $ok - set up a new store

$store->get(id) -> $node - retrieve a node object by id

$store->add(type) -> $node - create a new placeholder node. reserve the id.

$store->put(node) -> $ok - save a node, and update all indices

$store->del(id) -> $ok - remove a node, and update all indices

$store->schemata() -> { type => class } - get a map of the valid node classes

=head1 NOTES

- node schema needs to define what is indexed

- node schema comes from node class for now


