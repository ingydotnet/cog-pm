package CogWiki::App;
use Mouse;

sub handle_init {
    my $self = shift;
    throw Error "Can't init. Already is a cogwiki."
        if $self->config->is_wiki;
}

sub handle_make {
    my $self = shift;
    try {
        $self->app->make;
    }
    catch {
        chomp;
        throw Error "make failed.\n$_\n";
    };
}

sub handle_up {
    require Plack::Runner;
    require CogWiki::PSGI;
    my $self = shift;
    try {
        my $runner = Plack::Runner->new();
        $runner->parse_options(@{$self->argv});
        my $app = CogWiki::PSGI->new->app;
        $runner->run($app);
    }
    catch {
        chomp;
        XXX $_;
        throw Error "up failed.\n$_\n";
    };
}

sub handle_edit {
    my $class = shift;
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
    my $time = time;
    $newtext =~ s/^Time: +.*\n/Time: $time\n/m or die;
    io($filename)->print($newtext);

    system("generate_pages") == 0 or die;
}

1;
