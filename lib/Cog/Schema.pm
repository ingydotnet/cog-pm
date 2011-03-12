package Cog::Schema;
use Mouse;
extends 'Cog::Base';

use XXX;

has type => (is => 'ro');
has parent => (is => 'ro');
has fields => (is => 'ro');
has perl_class => (is => 'ro');

sub BUILD {
    my $self = shift;
    my $fields = $self->fields;
    for (my $i = 0; $i < @$fields; $i++) {
        my $field = $fields->[$i];
        next if ref($field);
        my ($name, $modifier) = ($field =~ /^(\w+)([\*\+\?])?$/g);
        my ($req, $list) =
            not(defined $modifier) ? (1, 0) :
            $modifier eq '?' ? (0, 0) :
            $modifier eq '*' ? (0, 1) :
            $modifier eq '+' ? (1, 1) :
            die;
        $fields->[$i] = Cog::Node::Schema::Field->new(
            name => $name,
            type => 'Str',
            req => $req,
            list => $list,
        );
    }
    return $self;
}

sub node_class {
    my $self = shift;
    return $self->perl_class
        if $self->perl_class;
    my $class = ref($self) or die;
    $class =~ s/::Schema$// or die;
    $self->generate_class($class);
    $self->{perl_class} = $class;
    return $class;
}

sub generate_class {
    my $self = shift;
    my $class = shift;
    my $type = $self->type;
    my $parent = $self->parent;
    $parent = 'Cog::Node' if $parent eq 'CogNode';
    my $code = <<"...";
package $class;
use Mouse;
extends '$parent';
use constant Type => '$type';

...
    for my $field (@{$self->fields}) {
        my $name = $field->name;
        $code .= "has $name => (is => 'ro');\n";
    }
    eval $code;
    die $@ if $@;
}

sub all_fields {
    my $self = shift;
    my @fields;
    my $schema = $self;
    while (1) {
        unshift @fields, @{$schema->fields};
        my $parent = $schema->parent or last;
        $schema = $self->store->schema_map->{$parent} or die;
    }
    return \ @fields;
}

package Cog::Node::Schema::Field;
use Mouse;

has name => (is => 'ro');
has type => (is => 'ro');
has req => (is => 'ro');
has list => (is => 'ro');

1;

