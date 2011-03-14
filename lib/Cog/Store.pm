# TODO:
# Split this into Cog::Store::CogFiles
package Cog::Store;
use Mouse;
extends 'Cog::Base';

use Cog::Node;
use Cog::Node::Schema;
use IO::All;
use Git::Wrapper;
use Convert::Base32::Crockford ();

use XXX;

has root => (is => 'ro', default => 'store');
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

sub exists {
    my $self = shift;
    return -e "$self->root/node";
}

sub init {
    my $self = shift;
    my $root = $self->root;
    die "Cog store already initialized"
        if -e "$root/node/_";
    io("$root/node/_")->assert->touch();
    io("$root/index/_")->assert->touch();
}

sub get {
    my $self = shift;
    my $id = shift;
    my $root = $self->root;
    my $io = io("$root/node/$id");
    die unless $io->exists;
    return $self->node_from_text($io->all);
}

sub add {
    my $self = shift;
    my $type = shift;
    return $self->schema_map->{$type}->node_class->new(
        Id => $self->new_id,
        Type => $type,
    );
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
        $prev = $self->schema_map->{$type}->node_class->new;
        io($anchor)->symlink("../../" . $ref);
    }
    else {
        $prev = $self->node_from_text(io($anchor)->all);
    }

    # update node (Time, Rev, etc)
    # delete prev content
    # write node to content
    # symlink node/id -> file.cog
    # diff node with prev

    $self->update($prev => $node);
    my $diff = $self->diff($prev, $node);
    $self->index_update($node, $diff);
    $self->view->update($node, $diff);
}

sub update {
#     my ($self, $prev, $node) = @_;
#     return $node unless $prev->Id;
#     die;
}

sub diff {
    my ($self, $prev, $node) = @_;
    my $type = $node->Type;
    my $diff = [];
    for my $field (@{$self->schema_map->{$type}->all_fields}) {
        my $f = $field->name;
        next if $f =~ /^(Id|Rev|Type|Time)$/;
#         next unless $field->index;
        if ($field->list) {
            my $o = $prev->$f || [];
            my $n = $node->$f || [];
            if (join('|', @$o) ne join ('|', @$n)) {
                push @$diff, map {['-', $f, $_]} @$o;
                push @$diff, map {['+', $f, $_]} @$n;
            }
        }
        else {
            my $o = $prev->$f || '';
            my $n = $node->$f || '';
            if ($o ne $n) {
                push @$diff, ['-', $f, $o] if $o;
                push @$diff, ['+', $f, $n] if $n;
            }
        }
    }
    return $diff;
}

sub index_update {
    my ($self, $node, $diff) = @_;
}

sub node_from_text {
    my $self = shift;
    my ($type) = ($_[0] =~ /^Type: +(\w+)$/gm) or die $_[0];
    return $self->schema_map->{$type}->node_class->from_text($_[0]);
}

# 2 - 352
# 3 - 15840
# 4 - 571648
# 5 - 19113600
# 6 - 615357952
# 7 - 19373544960
# 8 - 601207349248
sub new_id {
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
        warn $short;
        return $full
            unless $self->id_used($short, $full);
    }
}

sub id_used {
    my $self = shift;
    my $short = shift;
    my $full = shift;
    my $path = $self->root . '/node';
    die "missing node store"
        unless -e "$path/_";
    return 1 if -e "$path/$short";
    io("$path/$short")->symlink($full);
    return 0;
}

sub import_files {
    my $self = shift;
    my $files = shift;
    for my $path (@$files) {
        my $node = $self->content->node_from_reference($path);
        $self->put($node, $path);
    }
    $self->view->flush;
}

sub reserve_keys {
    my $self = shift;
    my $files = shift;
    for my $path (@$files) {
        my $node = $self->content->node_from_reference($path);
        $self->id_used($node->Short, $node->Id . " archived");
    }
}

sub transform_flatten {
    my $self = shift;
    my $name = shift;
    $name = lc($name);
    $name =~ s/[^a-z0-9]+/_/g;
    $name =~ s/^_*(.*?)_*$/$1/;
    $name ||= '_';
    return $name;
}
 
# This little guy handles all the index reads and writes!
sub index {
    my $self = shift;
    my $name = shift or die;
    my $key = @_ ? shift : '';
    my $index = "$self->root/index/$name";
    if (not @_) {
        if ($key eq '') {
            return [] unless -d $index;
            return [map $_->filename, io->dir($index)->all];
        }
        return unless -d "$index/$key";
        return [map $_->filename, io("$index/$key")->all];
    }
    io->file("$index/$key/$_")->assert->touch()
        for @_;
    return scalar @_;
}

sub unindex {
    my $self = shift;
    my $name = shift or die;
    my $key = shift or die;
    my $value = shift or die;
    my $file = "$self->root/index/$name/$key/$value";
    if (-f $file) {
        io->file($file)->unlink;
        return 1;
    }
    return 0;
}

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

$store->index(name) -> [ keys ] - get all keys of an index

$store->index(name, key) -> [ values ] - get all values of an index key

$store->index(name, key, value) -> $ok - add a value to an index key

$store->unindex(name, key, value) -> $ok - remove a value from an index key

=head1 NOTES

- node schema defines what is indexed

- node schema comes from node class for now


