package CogWiki::App;
use Mouse;
use IO::All;
use Class::Throwable qw(Error);

has config => (is => 'ro', 'required' => 1);
has store => (is => 'ro', builder => sub {
    require CogWiki::Store;
    CogWiki::Store->new();
});
has maker => (is => 'ro', builder => sub {
    my $self = shift;
    require CogWiki::Maker;
    CogWiki::Maker->new(
        config => $self->config,
        store => $self->store,
    );
});
has time => (is => 'ro', builder => sub { time() });

sub handle_init {
    my $self = shift;
    my $root = $self->config->root_dir;
    throw Error "Can't init. '$root/' already exists."
        if $self->config->is_init;

    $self->_copy_assets();

    CogWiki::Store->new(root => "$root/cog")->create;

    print <<"...";
CogWiki was successfully initialized in the $root/ subdirectory. The
next step is to:

    cp $root/config.yaml.example $root/config.yaml

Edit the config.yaml file, then run:

    cogwiki make

...
}

sub handle_update {
    my $self = shift;
    my $root = $self->config->root_dir;

    $self->_copy_assets();

    print <<"...";
CogWiki was successfully updated in the $root/ subdirectory.

Now run:

    cogwiki make

...
}

sub _copy_assets {
    my $self = shift;
    my $files = $self->_find_share_files;
    my $root = $self->config->root_dir;

    for my $file (keys %$files) {
        my $target = "$root/$file";
        unlink $target;
        if ($ENV{COGWIKI_SYMLINK_INSTALL}) {
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
CogWiki is up to date and ready to use. To start the wiki web server,
run this command:

    cogwiki start

...
    
}

sub handle_start {
    require CogWiki::WebApp;
    my $self = shift;
    $self->config->chdir_root();
    my $webapp = CogWiki::WebApp->new(config => $self->config);
    my $app = $webapp->app;
    print <<'...';
CogWiki web server is starting up...

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
    my $oldpage = CogWiki::Page->from_text($oldtext);
    my $rev = $oldpage->rev;

    system("vim $filename") == 0 or die;

    my $newtext = -e $filename ? io( $filename )->all : '';
#     my $newpage = CogWiki::Page->from_text($newtext);
    $rev++;
    $newtext =~ s/^Rev: +.*\n/Rev: $rev\n/m or die;
    my $time = $self->time;
    $newtext =~ s/^Time: +.*\n/Time: $time\n/m or die;
    io($filename)->print($newtext);

    system("generate_pages") == 0 or die;
}

# TODO Move most of this method to CogWiki::Page
sub handle_bless {
    my $self = shift;
    die "Run 'cogwiki init' first\n"
        unless $self->store->exists;
    my $dir = '.';
    for my $title (@_) {
        my $file = "$dir/$title";
        if (not -e $file) {
            warn "Can't bless '$title'. No such file.\n";
            next;
        }
        my ($head, $body) = $self->_read_page($file);
        my $original = $head . (($head and $body) ? "\n" : '') . $body;
        my $heading = '';
        $heading .= ($head =~ s/^(Wiki: .*\n)//m) ? $1 :
            "Wiki: cog 0.0.1\n";
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
    # TODO - Remove .wiki files except config.yaml (if present)
}

# TODO - Make real
sub _find_share_files {
    require File::ShareDir;
    my $self = shift;

    my $hash = {};

    my @plugins = ('CogWiki', @{$self->config->plugins});

    for my $plugin (@plugins) {
        my $module = $plugin;
        eval "use $plugin; 1" or die;
        my $object = $module->new;
        next unless $plugin eq 'CogWiki' or $object->layout;

        (my $path = "$plugin.pm") =~ s!::!/!g;
        $path = $INC{$path} or die;
        $path =~ s!^(\Q$ENV{HOME}\E.*)/lib/.*!$1/share!;
        my $dir = -e $path
            ? $path
            : do {
                (my $dist = $plugin) =~ s/::/-/g;
                eval { File::ShareDir::dist_dir($dist) } || do {
                    $_ = $@ or die;
                    /.* at (.*\/\.\.)/s or die;
                    "$1/share/";
                };
            };

        for (io->dir($dir)->All_Files) {
            my $full = $_->pathname;
            my $short = $full;
            $short =~ s!^\Q$dir\E/?!! or die;
            $hash->{$short} = $full;
        }
    }

    return $hash;
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
