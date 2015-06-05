package Cog::Schema;
use Mo qw'build default';
extends 'Cog::Base';

# use XXX;

has type => ();
has parent => ();
has fields => ();
has perl_class => ();

sub BUILD {
    my $self = shift;
    my $fields = $self->fields;
    for (my $i = 0; $i < @$fields; $i++) {
        my $field = $fields->[$i];
        my $index;
        if (ref($field) eq 'ARRAY') {
            ($field, $index) = @$field;
        }
        next if ref($field);
        my ($name, $modifier) = ($field =~ /^(\w+)([\*\+\?])?$/g);
        my ($req, $list) =
            not(defined $modifier) ? (1, 0) :
            $modifier eq '?' ? (0, 0) :
            $modifier eq '*' ? (0, 1) :
            $modifier eq '+' ? (1, 1) :
            die;
        $field = $fields->[$i] = Cog::Schema::Field->new(
            name => $name,
            type => 'Str',
            req => $req,
            list => $list,
        );
        next unless $index;
        my @args;
        if (ref($index) eq 'ARRAY') {
            ($index, @args) = @$index;
        }
        unless (ref($index)) {
            $index = Cog::Schema::Index->new(name => $index, @args);
        }
        $field->{index} = $index;
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
use Mo;
extends '$parent';
use constant Type => '$type';

...
    for my $field (@{$self->fields}) {
        my $name = $field->name;
        $code .= "has $name => ();\n";
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

package Cog::Schema::Field;
use Mo;

has name => ();
has type => ();
has req => ();
has list => ();
has index => ();

package Cog::Schema::Index;
use Mo qw'default';

has name => ();
has key => (default => '$v');
has value => (default => '$i');

1;
