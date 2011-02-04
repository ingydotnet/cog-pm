# TODO:
# - handle_new($type)
# - handle_stop
# - Customize App messages like the 'up' msg
# - pQuery plugins - cache based on html
package Cog::App;
use Mouse;
extends 'Cog::Base';

use Class::Throwable qw(Error);
use Cog::Config;
use IO::All;
use Getopt::Long qw(:config pass_through);
use YAML::XS;
use Cwd 'abs_path';

use XXX;

use constant Name => 'Cog';
use constant SHARE_DIST => 'Cog';
use constant app_root => ((-e '.cog') ? '.cog' : 'cog');
use constant command_script => 'cog';

use constant config_class => 'Cog::Config';
use constant webapp_class => '';
use constant store_class => 'Cog::Store';
use constant maker_class => 'Cog::Maker';
use constant page_class => 'Cog::Maker';
sub plugins { [] };
sub cog_classes {
    my $self = shift;
    return +{
        webapp => $self->webapp_class,
        config => $self->config_class,
        store => $self->store_class,
        maker => $self->maker_class,
        page => $self->page_class,
    }
}

has action => ( is => 'rw' );
has time => ( is => 'ro', builder => sub { time() } );

sub get_app_class {
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
        $ENV{COG_APP_CLASS} ||
        $class->app_from('.cog/config.yaml') ||
        $class->app_from('cog/config.yaml') ||
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

    my $config = $config_class->new($hash);
    Cog::Base->set_global_config_singleton_object($config);

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
    throw Error "Can't init. Cog environment already exists."
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

    $self->config->store->create;

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
        my $target = "$root/$file";
        if ($ENV{COG_APP_SYMLINK_INSTALL}) {
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
    $self->config->maker->make;
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
    $self->config->runner->run(@args);
}

sub handle_edit {
    my $self = shift;
    my $filename = shift or die "No filename supplied";
    die "Bad filename" if $filename =~ m/[\n\\]/;
    die "Too many args" if @_;

    my $oldtext = -e $filename ? io( $filename )->all : '';
    my $oldpage = Cog::Page->from_text($oldtext);
    my $rev = $oldpage->rev;

    system("vim $filename") == 0 or die;

    my $newtext = -e $filename ? io( $filename )->all : '';
#     my $newpage = Cog::Page->from_text($newtext);
    $rev++;
    $newtext =~ s/^Rev: +.*\n/Rev: $rev\n/m or die;
    my $time = $self->time;
    $newtext =~ s/^Time: +.*\n/Time: $time\n/m or die;
    io($filename)->print($newtext);

    system("generate_pages") == 0 or die;
}

# TODO Move most of this method to Cog::Page
sub handle_bless {
    my $self = shift;
    die "Run 'cog init' first\n"
        unless $self->store->exists;
    my $dir = '..';
    for my $title (@_) {
        my $file = "$dir/$title";
        if (not -e $file) {
            warn "Can't bless '$title'. No such file.\n";
            next;
        }
        my ($head, $body) = $self->_read_page($file);
        my $original = $head . (($head and $body) ? "\n" : '') . $body;
        my $heading = '';
        $heading .= ($head =~ s/^(Cog: .*\n)//m) ? $1 :
            "Cog: 0.0.1\n";
        $heading .= ($head =~ s/^(Id: +[A-Z2-9]{4}-[A-Z0-9]{22}\n)//m) ? $1 :
            "Id: " . $self->store->new_cog_id() . "\n";
        $heading .= ($head =~ s/^(Rev: [0-9]+\n)//m) ? $1 :
            "Rev: 1\n";
        $heading .= ($head =~ s/^(Time: [0-9]+\n)//m) ? $1 :
            "Time: ${\ $self->time}\n";
        $heading .= ($head =~ s/^(User: .*\n)//m) ? $1 :
            "User: $ENV{USER}\n";
        $heading .= ($head =~ s/^(Name: .*\n)//m) ? $1 :
            "Name: $title\n";
        while ($head =~ s/^(Name: .*\n)//m) {
            $heading .= $1;
        }
        while ($head =~ s/^(Tag: .*\n)//m) {
            $heading .= $1;
        }
        while ($head =~ s/^(Url: .*\n)//m) {
            $heading .= $1;
        }
        $head =~ s/^[A-Z].*\n//mg;
        $heading .= $head;

        my $text = $heading . ($body ? "\n" : '') . $body;
        if ($text eq $original) {
            print "No change to $title\n";
        }
        else {
            $heading =~ /^Id: +([A-Z2-7]{4})-/m
                or throw Error "No cog id for '$title':\n$heading";
            $heading =~ /^Time: +(\d+)$/m
                or throw Error "No time for '$title'";
            print "Updating $title\n";
            io($file)->print($text);
        }
    }
}

sub handle_clean {
    # TODO - Remove .cog files except config.yaml (if present)
}

sub _read_page {
    my $self = shift;
    my $file = shift;
    my ($head, $body) = ('', '');
    my $page = io($file);
    if ($page->exists) {
        my $text = $page->all;
        if ($text =~ s/\A((?:[\w\-]+:\ .*\n)+)(\n|\z)//) {
            $head = $1;
        }
        $body = $text;
    }
    return ($head, $body);
}

1;
