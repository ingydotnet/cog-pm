package CogWiki::App;
use Mouse;
use IO::All;
use CogWiki::Store;
use Class::Throwable qw(Error);

use XXX;

has config => (is => 'ro', 'required' => 1);
has store => (
    is => 'ro',
    builder => sub {
        my $self = shift;
        CogWiki::Store->new(root => $self->config->root_dir . '/cog');
    },
);
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

# TODO - Make real
sub _find_share_files {
    require File::ShareDir;
    my $self = shift;

    my $dir = eval { File::ShareDir::dist_dir('CogWiki') } || do {
        $_ = $@ or die;
        /.* at (.*\/\.\.)/s or die;
        "$1/share/";
    };
    my $hash = {};
    %$hash = map {
        my $full = $_->pathname;
        my $short = $full;
        $short =~ s!^\Q$dir\E/?!! or die;
        ($short, $full);
    } io($dir)->All_Files;
    return $hash;
}

sub handle_make {
    eval "use Template::Toolkit::Simple; 1" or die $@;
    require CogWiki::Page;
    require IPC::Run;
    require JSON;
    require Time::Duration;

    my $self = shift;
    $self->config->chdir_root();

    my $json = JSON->new;
    $json->allow_blessed;
    $json->convert_blessed;

    io('cache')->mkdir;
    my $data = +{%{$self->config}};
    my $html = tt()
        ->path(['template/'])
        ->data($data)
        ->post_chomp
        ->render('layout.html.tt');
    io('cache/index.html')->print($html);

    $data = {
        json => $json->encode(YAML::XS::LoadFile("config.yaml")),
    };
    my $javascript = tt()
        ->path(['template/'])
        ->data($data)
        ->post_chomp
        ->render('config.js.tt');
    io('cache/config.js')->print($javascript);

    my $news = [];
    for my $page_file (io($self->config->content_root)->all_files) {
        next if $page_file->filename =~ /^\./;
        my $page = CogWiki::Page->from_text($page_file->all);
        my $id = $page->id;
        $id =~ s/-.*// or next;
        my $duration = Time::Duration::duration($page->time, 1);

        push @$news, {
            id => $id,
            rev => $page->rev,
            title => $page->title,
            time => $page->time,
            size => length($page->content),
            duration => $duration,
        };

        my $html_filename = "cache/$id.html";

        next if -e $html_filename and -M $html_filename < -M $page_file->name;

        my ($in, $out, $err) = ($page->content, '', '');

        my @cmd = qw(asciidoc -s -);
        
        print $page_file->filename . " -> $html_filename\n";
        IPC::Run::run(\@cmd, \$in, \$out, \$err, IPC::Run::timeout(10));

        io($html_filename)->assert->print($out);

        delete $page->{content};
        io("cache/$id.json")->print($json->encode({%$page}));
    }
    io("cache/news.json")->print($json->encode($news));

    print <<'...';
CogWiki is up to date and ready to use. To start the wiki web server,
run this command:

    cogwiki up

...
    
}

sub handle_up {
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
        my ($head, $body) = $self->read_page($file);
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

sub read_page {
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
