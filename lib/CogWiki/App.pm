package CogWiki::App;
use Mouse;
use IO::All;

use XXX;

sub handle_init {
    my $self = shift;
    throw Error "Can't init. .wiki/ already exists."
        if $self->config->is_init;

    my $config_file = _find_share_file($self, 'config.yaml');
    my $config = io($config_file)->all;
    io('.wiki/config.yaml')->assert->print($config);
}

# TODO - Make real
sub _find_share_file {
    my $self = shift;
    my $file = shift;
    return '../share/config.yaml';
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
    require CogWiki::WebApp;
    my $self = shift;
    my $webapp = CogWiki::WebApp->new(config => $self->config);
    my $app = $webapp->app;
    $webapp->run($app);
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
