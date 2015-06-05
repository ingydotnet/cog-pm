# TODO:
# - from_cog
# - to_cog
# - as_html
# - add validation to setters
package Cog::Node;
use Mo qw'default';

# use XXX;

has Id => ();
has Rev => (default => 1, lazy => 1);
has Type => ();
has Time => ();
has User => ();
has Name => (default => sub {[]} );
has Tag => (default => sub {[]}, lazy => 1 );
has Url => (default => sub {[]}, lazy => 1 );
has From => ();
has Body => ();
has Format => ();

sub Title {
    my $self = shift;
    return $self->Name->[0] || '';
}

sub Short {
    my $self = shift;
    $self->Id =~ m!^(\w{4,})-! or return '';
    return $1;
}

sub from_text {
    my $class = shift;
    my $text = shift;
    my $type = $class->Type;

    my $schema = Cog::Base->store->schema_map->{$type};

    my $head = ($text =~ s/\A((?:[\w\-]+:\ .*\n)+)(\n|\z)//) ? $1 : '';

    my %hash;

    for my $field (@{$schema->all_fields}) {
        my ($name, $req, $list) = @{$field}{qw(name req list)};
        while ($head =~ s/^($name): +(.*)\n//m) {
            my $value = $2;
            $value =~ s/^\s*(.*?)\s*$/$1/;
            if ($list) {
                $hash{$name} ||= [];
                push @{$hash{$name}}, $value;
            }
            else {
                $hash{$name} = $value;
            }
        }
    }
    # throw Error "Can't parse:\n$head" if $head;

    $hash{Body} = $text;
    my $self = $class->new(%hash);
    return $self;
}

sub to_text {
    my $self = shift;
    my $text = '';

    my $schema = Cog::Base->store->schema_map->{$self->Type};
    for my $field (@{$schema->all_fields}) {
        my ($name, $req, $list) = @{$field}{qw(name req list)};
        next if $name eq 'Body';
        my $value = $self->$name;
        next unless defined $value and length($value);
        if ($list) {
            for my $elem (@$value) {
                $text .= "${name}: $elem\n";
            }
        }
        else {
            $text .= "${name}: $value\n";
        }
    }
    if (defined $self->Body) {
        my $Body = $self->Body;
        chomp $Body;
        if (length $Body) {
            $text .= "\n$Body\n";
        }
    }

    return $text;
}

1;
