package Cog::WebApp;
use Mouse;
use Plack::Middleware::Static;
use Plack::Runner;

has config => (is => 'ro', required => 1);

my $layout_file = 'cache/layout.html';

sub app {
    my $self = shift;

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
    my @args = @_;
    my $runner = Plack::Runner->new;
    $runner->parse_options(@args);
    $runner->run($class->app);
}

1;
