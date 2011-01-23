package Cog::App;
use Mouse;
extends 'Cog::Base';

use Class::Throwable qw(Error);
use Cog::Config;
use IO::All;
use Getopt::Long();
use YAML::XS;

# use XXX;

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

has action => ( is => 'ro' );
has argv => ( is => 'ro', default => sub {[]} );
has time => ( is => 'ro', builder => sub { time() } );

sub new_app_object {
    my ($class, $script, @argv) = @_;
    my ($file, $app_class, $server);
    {
        local @ARGV = @argv;
        Getopt::Long::GetOptions(
            'file=s' => \$file,
            'app=s' => \$app_class,
            'server=s' => \$server,
        );
        @argv = (@ARGV, ($server ? ('-s' => $server) : ()));
    }
    my $config_file = $class->config_file($file);
    my $hash = {};
    if ($config_file) {
        $hash = YAML::XS::LoadFile($config_file);
    }
    $app_class ||= $hash->{app_class};
    die "Can't find the Cog::App class to use"
        unless $app_class;
    eval "require $app_class; 1" or die $@;

    my $app = $app_class->new(%{$class->_parse_args($script, @argv)});

    return $app;
}

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my $config_class = $class->config_class;
    my $config_file = $class->config_file
        or die "Can't determine config file";

    my $root_dir = '.';

    if ($config_file =~ /(.*)\/(.*)/) {
        ($root_dir, $config_file) = ($1, $2);
    }

    my $config_path = "$root_dir/$config_file";
    my $hash = -e $config_path
        ? YAML::XS::LoadFile($config_path)
        : {};
    $hash->{root_dir} = $root_dir;
    $hash->{config_file} = $config_file;
    $hash->{maker_class} = $class->maker_class;
    $hash->{store_class} = $class->store_class;

    my $config = $config_class->new($hash);
    Cog::Base->set_global_config_singleton_object($config);

    return $class->$orig(@_);
};

sub config_file {
    my $class = shift;
    my $argument = shift || '';
    my $config_file = 
        $ENV{COG_APP_CONFIG_FILE} ||
        -e('cog.config.yaml') && 'cog.config.yaml' ||
        '';
    return $config_file;
}

sub run {
    my $self = shift;
    my $action = $self->action;
    my $method = "handle_$action";
    my ($object, $function);

    $function = ($object = $self)->can($method)
        or throw Error "'$action' is an invalid action\n";
    $function->($object, @{$self->argv});
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
    elsif (@argv and $argv[0] =~ /^[\w\-]+$/) {
        $args->{action} = shift @argv;
        $args->{action} =~ s/-/_/g;
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

sub handle_init {
    my $self = shift;
    my $plugin = shift || 'Cog';
    my $root = $self->config->root_dir;
    throw Error "Can't init. Cog environment already exists."
        if $self->config->is_init;

    $self->_copy_assets();

    my $config_file = "$root/config.yaml";
    if (not -e $config_file) {
        require Template::Toolkit::Simple;
        my $data = +{%$self};
        $data->{plugin} = $plugin;
        my $config = Template::Toolkit::Simple::tt()
            ->path(["$root/template/"])
            ->data($data)
            ->post_chomp
            ->render('config.yaml.tt');
        io($config_file)->print($config);
    }

    Cog::Store->new(root => "$root/cog")->create;

    print <<"...";
Cog was successfully initialized in the $root/ subdirectory. The
next step is to edit the config.yaml file. Then run:

    cog update

...
}

sub handle_update {
    my $self = shift;
    my $root = $self->config->root_dir;

    $self->_copy_assets();

    print <<"...";
Cog was successfully updated in the $root/ subdirectory.

Now run:

    cog make

...
}

sub _copy_assets {
    my $self = shift;
    my $files = $self->config->files_map;
    my $root = $self->config->root_dir;

    for my $file (keys %$files) {
        my $target = "$root/$file";
        unlink $target;
        if ($ENV{COG_APP_SYMLINK_INSTALL}) {
            io($target)->assert->symlink($files->{$file});
        }
        else {
            io($target)->assert->print(io($files->{$file})->all);
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
    $self->config->chdir_root();
    print <<'...';
Cog web server is starting up...

...
    my @args = @_;
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
    $self->config->chdir_root();
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
