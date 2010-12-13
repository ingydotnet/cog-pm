package CogWiki::Page;
use Mouse;
use Time::Duration;

has id => ( is => 'rw' );
has rev => ( is => 'rw' );
has time => ( is => 'rw' );
has user => ( is => 'rw' );
has name => ( is => 'rw', default => sub {[]} );
has tag => ( is => 'rw', default => sub {[]} );
has url => ( is => 'rw', default => sub {[]} );
has content => ( is => 'rw' );
has title => ( is => 'rw' );
has short => ( is => 'rw' );
has size => ( is => 'rw' );
has color => ( is => 'rw' );
has duration => ( is => 'rw' );

sub from_file {
    my $self = shift;
}

sub to_file {
    my $self = shift;
}

sub from_text {
    my $class = shift;
    my $text = shift;

    my %hash;
    my $head = ($text =~ s/\A((?:[\w\-]+:\ .*\n)+)(\n|\z)//) ? $1 : '';
    while ($head =~ s/\A(\w+): +(.*)\n//) {
        my $key = lc $1;
        my $value = $2;
        if ($key =~ /^(?:name|tag|url)$/) {
            $hash{$key} ||= [];
            push @{$hash{$key}}, $value;
        }
        else {
            $hash{$key} = $value;
        }
    }
    throw Error "Can't parse:\n$head" if $head;

    $hash{content} = $text;
    my $self = $class->new(%hash);
    $self->title($self->name->[0] || '???');
    my $short = $self->id;
    $short =~ s/-.*//;
    $self->short($short);
    $self->size(length $text);
    $self->duration(Time::Duration::duration(time - $self->time, 1));
    return $self;
}

sub to_text {
    my $self = shift;
    my %keys = map ($_, 1), keys %$self;
}

1;
