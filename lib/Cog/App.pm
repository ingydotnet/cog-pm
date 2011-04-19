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
use constant app_root => abs_path('.');
use constant command_script => 'cog';

# XXX Make these more dynamic so subclasses don't have to always override
use constant config_class => 'Cog::Config';
use constant content_class => 'Cog::Content';
use constant maker_class => 'Cog::Maker';
use constant store_class => 'Cog::Store';
use constant webapp_class => '';
use constant view_class => 'Cog::View';

sub plugins { [] };
# XXX - Is this still needed??
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
    @ARGV = @argv;
    Getopt::Long::GetOptions(
        'app=s' => \$app_class,
    );
    $app_class ||= $ENV{COG_APP} || $class;
    unless ($app_class->can('new')) {
        eval "use $app_class; 1"
            or die $@;
    }
    die "$app_class is not a Cog::App application"
        unless $app_class->isa('Cog::App') and
            $app_class ne 'Cog::App';

    return $app_class;
}

sub BUILD {
    my ($self) = @_;
    my $config_class = $self->config_class;
    eval "require $config_class"
        unless UNIVERSAL::can($config_class, 'new');
    my $config_file = $self->config_file
        or die "Can't determine config file";

    my $app_root = '.';

    if ($config_file =~ /(.*)\/(.*)/) {
        ($app_root, $config_file) = ($1, $2);
    }

    my $hash = -e $config_file
        ? YAML::XS::LoadFile($config_file)
        : {};
    $hash = {
        %$hash,
        app_root => abs_path($app_root),
        config_file => $config_file,
        app_class => ref($self),
        maker_class => $self->maker_class,
        store_class => $self->store_class,
        command_script => $0,
        command_args => [@ARGV],
    };

    Cog::Base->initialize(
        $self,
        $config_class->new($hash),
    );
}

sub config_file {
    my $class = shift;
    return $class->app_root . '/' . lc($class->Name) . '.conf.yaml';
}

sub run {
    my $self = shift;

    $self->parse_command_args;

    my $action = $self->action;
    my $method = "handle_$action";

    my $function = $self->can($method)
        or throw Error "'$action' is an invalid action\n";

    $self->chdir_root()
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

    $self->chdir_root;

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

# Put the App in the context of its defined root directory.
sub chdir_root {
    my $self = shift;
    my $app_root = $self->config->app_root;
    chdir $app_root
      or die "Can't chdir into $app_root";
}

1;
