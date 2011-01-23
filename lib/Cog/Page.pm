package Cog::Page;
use Mouse;
use Time::Duration ();

# use XXX;

sub SCHEMA {
    return (
        'Id',
        'Type',
        'Name+',
        'Tag*',
        'Url*',
    )
}

my $time = time;
has Id => (is => 'rw');
has Type => (is => 'rw');
# XXX default is just a temporary workaround
has Rev => (is => 'rw', default => 1, lazy => 1);
# XXX default is just a temporary workaround
has Time => (is => 'rw', default => $time - 3600, lazy => 1);
has User => (is => 'rw');
has Name => (is => 'rw', default => sub {[]} );
has Tag => (is => 'rw', default => sub {[]}, lazy => 1 );
has Url => (is => 'rw', default => sub {[]}, lazy => 1 );
has Content => (is => 'rw');

has duration => (is => 'rw', builder => sub {
    return Time::Duration::duration($time - $_[0]->Time, 1);
});

# sub from_file {
#     my $self = shift;
# }

# sub to_file {
#     my $self = shift;
# }

sub Title {
    my $self = shift;
    return $self->Name->[0] or '---';
}

sub Short {
    my $self = shift;
    $self->Id =~ m!^(\w{4,})-! or return;
    return $1;
}

sub from_text {
    my $class = shift;
    my $text = shift;

    my $head = ($text =~ s/\A((?:[\w\-]+:\ .*\n)+)(\n|\z)//) ? $1 : '';

    my %hash;

    my @schema = $class->SCHEMA;
    for my $field (@schema) {
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
    $self->duration(Time::Duration::duration(time - $self->Time, 1));
    return $self;
}

# sub to_text {
#     my $self = shift;
#     my %keys = map ($_, 1), keys %$self;
# }

1;
