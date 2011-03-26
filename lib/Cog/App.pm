# TODO:
# - handle_stop
package Cog::App;
use Mouse;
extends 'Cog::Base';

use Class::Throwable qw(Error);
use Cog::Config;
use IO::All;
use Getopt::Long qw(:config pass_through);
use YAML::XS;
use Cwd 'abs_path';

# use XXX;

use constant Name => 'Cog';
# use constant app_root => 'cog';
use constant app_root => (
    (-e '.cog') ? '.cog' :
    (-e 'cog') ? 'cog' :
    '.'
);
use constant command_script => 'cog';

use constant config_class => 'Cog::Config';
use constant content_class => 'Cog::Content';
use constant maker_class => 'Cog::Maker';
use constant store_class => 'Cog::Store';
use constant webapp_class => '';
use constant view_class => 'Cog::View';

sub plugins { [] };
sub cog_classes {
    my $self = shift;
    return +{
        config => $self->config_class,
        content => $self->content_class,
        maker => $self->maker_class,
        store => $self->store_class,
        webapp => $self->webapp_class,
        view => $self->view_class,
    }
}

has action => ( is => 'rw' );
has time => ( is => 'ro', builder => sub { time() } );

sub get_app {
    my ($class, @argv) = @_;
    my $app_class;
    {
        local @ARGV = @argv;
        Getopt::Long::GetOptions(
            'app=s' => \$app_class,
        );
        @argv = @ARGV;
    }
    $app_class ||=
        $ENV{COG_APP} ||
        $class->app_from($class->app_root . '/config.yaml') ||
        die "Can't determine Cog App class";
    unless ($app_class->can('new')) {
        eval "use $app_class; 1"
            or die $@;
    }
    die "$app_class is not a Cog::App application"
        unless $app_class->isa('Cog::App') and
            $app_class ne 'Cog::App';
    return ($app_class, @argv);
}

sub app_from {
    my $class = shift;
    my $config_path = shift;
    return unless -e $config_path;
    my $hash = YAML::XS::LoadFile($config_path);
    my $app_class = $hash->{app_class}
        or die "'app_class' is not defined in $config_path";
}

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my $config_class = $class->config_class;
    my $config_file = $class->config_file
        or die "Can't determine config file";

    my $app_root = '.';

    if ($config_file =~ /(.*)\/(.*)/) {
        ($app_root, $config_file) = ($1, $2);
    }

    $app_root = abs_path($app_root) || $app_root;
    my $config_path = abs_path("$app_root/$config_file") || '';
    $config_path = ''
        unless -e $config_path;
    my $hash = $config_path
        ? YAML::XS::LoadFile($config_path)
        : {};
    die "'app_class' must be defined in '$config_path'"
        if -e $config_path and not $hash->{app_class};
    $hash->{app_class} ||= $class;
    $hash->{app_root} = $app_root;
    $hash->{config_file} = $config_file;
    $hash->{maker_class} = $class->maker_class;
    $hash->{store_class} = $class->store_class;

    Cog::Base->initialize($config_class->new($hash));

    return $class->$orig(@_);
};

sub config_file {
    my $class = shift;
    return $class->app_root . "/config.yaml";
}

sub run {
    my $self = shift;

    $self->parse_command_args;

    my $action = $self->action;
    my $method = "handle_$action";

    my $function = $self->can($method)
        or throw Error "'$action' is an invalid action\n";

    $self->config->chdir_root()
        unless $action eq 'init';

    $function->($self);
    return 0;
}

sub parse_command_args {
    my $self = shift;
    my $argv = $self->config->command_args;
    my $script = $self->config->command_script;
    $script =~ s!.*/!!;
    my $action = '';
    if ($script =~ /^(pre-commit|post-commit)$/) {
        $script =~ s/-/_/;
        $self->action($script);
    }
    elsif ($script ne $self->command_script) {
        throw Error "unexpected script name '$script'\n";
    }
    elsif (@$argv and $argv->[0] =~ /^[\w\-]+$/) {
        $action = shift @$argv;
        $action =~ s/-/_/g;
    }
    elsif (not @$argv) {
        $action = 'help';
    }
    else {
        require XXX;
        warn "\nInvalid cog command. Can't parse these arguments:\n";
        XXX::XXX(@_);
    }
    $self->action($action);
    $self->config->command_args($argv);
}

#-----------------------------------------------------------------------------
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

sub handle_init {
    my $self = shift;
    my $root = $self->config->app_root;
    throw Error "Can't init. Cog environment already exists.\n"
        if $self->config->is_init;

    $self->_copy_assets();

    my $config_file = "$root/config.yaml";
    if (not -e $config_file) {
        require Template::Toolkit::Simple;
        my $data = +{%$self};
        $data->{app_class} = ref($self);
        my $config = Template::Toolkit::Simple::tt()
            ->path(["$root/template/"])
            ->data($data)
            ->post_chomp
            ->render('config.yaml.tt');
        io($config_file)->print($config);
    }

    $self->config->chdir_root;

    $self->store->init;

    my $Name = $self->Name;
    my $name = $self->config->command_script;
    $name =~ s!.*/!!;

    print <<"...";
$Name was successfully initialized in:

    $root

The next step is to edit:

    $config_file
    
Then run:

    $name update

...
}

sub handle_update {
    my $self = shift;
    my $root = $self->config->app_root;

    $self->_copy_assets();

    my $Name = $self->Name;
    my $name = $self->config->command_script;
    $name =~ s!.*/!!;

    print <<"...";
$Name was successfully updated in the $root/ subdirectory.

Now run:

    $name make

...
}

sub _copy_assets {
    my $self = shift;
    my $files = $self->config->files_map;
    my $root = $self->config->app_root;

    for my $file (keys %$files) {
        my $source = $files->{$file};
        my $target = $file =~ m!^(js|css|image)/!
            ? "$root/static/$file"
            : "$root/$file";
        if ($ENV{COG_SYMLINK_INSTALL}) {
            unless (-l $target and readlink($target) eq $source) {
                unlink $target;
                io($target)->assert->symlink($source);
                print "> link $source => $target\n";
            }
        }
        else {
            unless (-f $target and not(-l $target) and io($target)->all eq io($source)->all) {
                unlink $target;
                io($target)->assert->print(io($source)->all);
                print "> copy $source => $target\n";
            }
        }
    }
}

sub handle_make {
    my $self = shift;
    $self->maker->make;
    print <<'...';
Cog is up to date and ready to use. To start the web server, run
this command:

    cog start

...
    
}

sub handle_start {
    my $self = shift;
    print <<'...';
Cog web server is starting up...

...
    my @args = @{$self->config->command_args};
    unshift @args, ('-p' => $self->config->server_port)
        if $self->config->server_port;
    $self->runner->run(@args);
}

sub handle_edit {
    # TODO
}

sub handle_clean {
    my $self = shift;
    $self->maker->make_clean;
    print <<'...';
Cog is clean. To rebuild, run this command:

    cog make

...
    
}

1;
