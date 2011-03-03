# TODO:
# - from_cog
# - to_cog
# - as_html
# - add validation to setters
package Cog::Node;
use Mouse;

# use XXX;

sub SCHEMA {
    return (
        'Id',
        'Rev',
        'Type',
        'Time',
        'User',
        'Name*',
        'Tag*',
        'Url*',
        'Content?',
    )
}

my $time = time;
has Id => (is => 'rw');
# XXX default is just a temporary workaround
has Rev => (is => 'rw', default => 1, lazy => 1);
has Type => (is => 'rw');
# XXX default is just a temporary workaround
has Time => (is => 'rw', default => $time - 3600, lazy => 1);
has User => (is => 'rw');
has Name => (is => 'rw', default => sub {[]} );
has Tag => (is => 'rw', default => sub {[]}, lazy => 1 );
has Url => (is => 'rw', default => sub {[]}, lazy => 1 );
has Content => (is => 'rw');

# sub from_cog_file {
#     my $self = shift;
# }

# sub to_cog_file {
#     my $self = shift;
# }

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

    my $head = ($text =~ s/\A((?:[\w\-]+:\ .*\n)+)(\n|\z)//) ? $1 : '';

    my %hash;

    for my $field ($class->SCHEMA) {
        $field =~ s/([\?\+\*]?)$//;
        my $mod = $1 || '';
        my $list = ($mod =~ /[\+\*]/);
        my $optional = ($mod =~ /[\*\?]/);
        while ($head =~ s/^($field): +(.*)\n//m) {
            my $value = $2;
            $value =~ s/^\s*(.*?)\s*$/$1/;
            if ($list) {
                $hash{$field} ||= [];
                push @{$hash{$field}}, $value;
            }
            else {
                $hash{$field} = $value;
            }
        }
    }
    # throw Error "Can't parse:\n$head" if $head;

    $hash{Content} = $text;
    my $self = $class->new(%hash);
    return $self;
}

sub to_text {
    my $self = shift;
    my $text = '';

    for my $field ($self->SCHEMA) {
        $field =~ s/([\?\+\*]?)$//;
        next if $field eq 'Content';
        my $mod = $1 || '';
        my $list = ($mod =~ /[\+\*]/);
        my $optional = ($mod =~ /[\*\?]/);
        next unless defined $self->{$field};
        my $value = $self->{$field};
        if ($list) {
            for my $elem (@$value) {
                $text .= "${field}: $elem\n";
            }
        }
        else {
            $text .= "${field}: $value\n";
        }
    }
    if (defined $self->{Content}) {
        my $Content = $self->{Content};
        chomp $Content;
        if (length $Content) {
            $text .= "\n$Content\n";
        }
    }

    return $text;
}

# sub to_text {
#     my $self = shift;
#     my %keys = map ($_, 1), keys %$self;
# }

1;
