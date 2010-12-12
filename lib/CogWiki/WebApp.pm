package CogWiki::WebApp;
use Mouse;
use Plack::Middleware::Static;
use Plack::Runner;

# use XXX;

has config => (is => 'ro', required => 1);

sub app {
    my $self = shift;

    my $layout_file = 'cache/layout.html';
    open LAYOUT, $layout_file or die "Can't open '$layout_file'";
    my $layout = do {local $/; <LAYOUT>};
    close LAYOUT or die;

    my $app = sub {
        return [ 200, [ 'Content-Type' => 'text/html' ], [ $layout ] ];
    };
    if ($self->config->plack_debug) {
        require Plack::Middleware::Debug;
        $app = Plack::Middleware::Debug->wrap($app);
    }
    $app = Plack::Middleware::Static->wrap($app, path => qr{^/(static|cache)/}, root => './');
    return $app;
}

sub run {
    my $class = shift;
    my $runner = Plack::Runner->new;
    my @args = @_;

    $runner->parse_options(@args);
    $runner->run($class->app);
}

1;
