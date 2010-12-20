package Cog::App;
use Mouse;
use IO::All;
use Class::Throwable qw(Error);

# use XXX;

has config => (is => 'ro', 'required' => 1);
has store => (is => 'ro', builder => sub {
    require Cog::Store;
    Cog::Store->new();
});
has maker => (is => 'ro', builder => sub {
    my $self = shift;
    require Cog::Maker;
    Cog::Maker->new(
        config => $self->config,
        store => $self->store,
    );
});
has time => (is => 'ro', builder => sub { time() });

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
        if ($ENV{COG_SYMLINK_INSTALL}) {
            io($target)->assert->symlink($files->{$file});
        }
        else {
            io($target)->assert->print(io($files->{$file})->all);
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
    require Cog::WebApp;
    my $self = shift;
    $self->config->chdir_root();
    my $webapp = Cog::WebApp->new(config => $self->config);
    my $app = $webapp->app;
    print <<'...';
Cog web server is starting up...

...
    my @args = @_;
    unshift @args, ('-p' => $self->config->server_port)
        if $self->config->server_port;
    $webapp->run($app, @args);
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
        $heading .= ($head =~ s/^(Id: +[A-Z2-7]{4}-[A-Z2-7]{22}\n)//m) ? $1 :
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
