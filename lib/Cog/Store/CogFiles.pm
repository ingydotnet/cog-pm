# TODO:
# - Make cogbase indexes
#   - title to id
package Cog::Store::CogFiles;
use Mouse;
extends 'Cog::Store';

use IO::All;
use Git::Wrapper;
use Convert::Base32::Crockford ();

use XXX;

has root => (is => 'ro', default => 'store');

srand();

sub exists {
    my $self = shift;
    return -e "$self->root/node";
}

sub id_used {
    my $self = shift;
    my $short = shift;
    my $full = shift;
    my $path = $self->root . '/node';
    die "missing node store"
        unless -e "path/_";
    return if -e "$path/$short";
    io("$path/$short")->symlink($full);
    return 1;
}

sub init {
    my $self = shift;
    my $root = $self->root;
    die "Cog store already initialized"
        if -e "$root/node/_";
    io("$root/node/_")->assert->touch();
    io("$root/index/_")->assert->touch();
}

sub put {
    my $self = shift;
    my $node = shift;
    my $prev;
    my $ref = $self->content->node_reference($node);
    my $root = $self->root or die;
    my $id = $node->Short or die;
    my $type = $node->Type or die;
    my $anchor = "$root/node/$id";

    if (not -e $anchor) {
        $prev = $self->store->schema_map->{$type}->node_class;
        io($anchor)->symlink("../../" . $ref);
    }
    # if no node/id
      # Create symlink of node/id -> file.cog
      # $prev = empty_node
    # else
      # $prev = get prev node
    # update node (Time, Rev, etc)
    # delete prev content
    # write node to content
    # symlink node/id -> file.cog
    # diff node with prev
    # foreach (@diff)
      # update appropriate index
        # Check schema for index
      # update appropriate view

    io($self->root . '/node/' . $id)->symlink($ref);
}

# 2 - 352
# 3 - 15840
# 4 - 571648
# 5 - 19113600
# 6 - 615357952
# 7 - 19373544960
# 8 - 601207349248
sub new_cog_id {
    my $self = shift;
    my $path = $self->root . '/node';
    my ($full, $short);
    while (1) {
        # Base32 125bit random number.
        my $id = uc Convert::Base32::Crockford::encode_base32(
            join "", map { pack "S", int(rand(65536)) } 1..8
        ); 
        chop $id;
        $id =~ s/(....)(.*)/$1-$2/ or die;
        $short = $1;
        next unless
            ($short =~/[2-9]/ and $short =~ /[A-Z]/ and $short !~ /[01]/);
        next if -e "$path/$short";
        $full = $id;
        last;
    }
    io("$path/$short")->print($full);
    return $full;
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
