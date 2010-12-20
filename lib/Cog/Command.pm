package Cog::Command;
use Mouse;
use Try::Tiny;
use Class::Throwable qw(Error);
use Cog::Config;
use IO::All;

# use XXX;

has config => (is => 'ro', builder => sub {Cog::Config->new()});
has app => (is => 'ro', builder => '_app_builder');
has action => (is => 'ro');
has argv => (is => 'ro', default => sub {[]});

around BUILDARGS => sub {
    my ($orig, $class) = splice @_, 0, 2;
    $class->$orig($class->_parse_args(@_));
};

sub _app_builder {
    my $self = shift;
    require Cog::App;
    return Cog::App->new(config => $self->config);
}

sub run {
    my $self = shift;
    my $action = $self->action;
    my $method = "handle_$action";
    my ($object, $function);

    $function =
        ($object = $self)->can($method) ||
        ($object = $self->app)->can($method)
        or throw Error "'$action' is an invalid action\n";
    try {
        $function->($object, @{$self->argv});
    }
    catch {
        s/^Error : //;
        throw Error "'$action' failed:\n$_\n";
    };
    return 0;
}

sub handle_help {
    my $self = shift;
    print $self->usage;
}

sub usage {
    my $self = shift;
    return <<'...';
Usage: cog command

Commands:
    init   - Make current directory into a Cog app
    init Cog::Class
           - Make a Cog::Class app specifically
    update - Update the app with the latest assets
    make   - Prepare the app content for the web
    start  - Start the local app server
    stop   - Stop the server

    bless file-name - Turn a text file into a cog file
    edit name|id - Start an editor with the contents of the cog page

See:
    `perldoc cog` - Documentation on this command.
    `perldoc Cog::Manual` - Complete Cog documentation.
...
}

sub _parse_args {
    my $class = shift;
    my ($script, @argv) = @_;
    my $args = {};
    $script =~ s!.*/!!;
    if ($script =~ /^(pre-commit|post-commit)$/) {
        ($args->{action} = $script) =~ s/-/_/;
    }
    elsif ($script ne 'cog') {
        throw Error "unexpected script name '$script'\n";
    }
    elsif (@argv and $argv[0] =~ /^\w+$/) {
        $args->{action} = shift @argv;
        $args->{argv} = [@argv];
    }
    elsif (not @argv) {
        $args->{action} = 'help';
    }
    else {
        require XXX;
        warn "\nInvalid cog command. Can't parse these arguments:\n";
        XXX::XXX(@_);
    }
    return $args;
}

1;
