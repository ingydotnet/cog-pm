package Cog::WebApp;
use Mouse;
use Plack::Middleware::Static;
use Plack::Middleware::ConditionalGET;
use Plack::Middleware::ETag;
use Plack::Middleware::Header;
use Plack::Runner;

has config => (is => 'ro', required => 1);

my $layout_file = 'cache/layout.html';

sub app {
    my $self = shift;

    open LAYOUT, $layout_file or die "Can't open '$layout_file'";
    my $layout = do {local $/; <LAYOUT>};
    close LAYOUT or die;
    print "calling app\n";

    my $time = scalar(gmtime);
    $time .= ' GMT' unless $time =~ /GMT/;

    my $app = sub {
        return [ 200, [
            'Content-Type' => 'text/html',
            'Last-Modified' => $time,
        ], [ $layout ] ];
    };
    if ($self->config->plack_debug) {
        require Plack::Middleware::Debug;
        $app = Plack::Middleware::Debug->wrap($app);
    }
    $app = Plack::Middleware::Static->wrap($app, path => qr{^/(static|cache)/}, root => './');
    $app = Plack::Middleware::ConditionalGET->wrap($app);
    $app = Plack::Middleware::ETag->wrap($app, file_etag => [qw/inode mtime size/]);
    $app = Plack::Middleware::Header->wrap($app, set => ['Cache-Control' => 'no-cache']);
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
