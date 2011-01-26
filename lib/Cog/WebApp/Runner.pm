package Cog::WebApp::Runner;
use Mouse;
extends 'Cog::Base';

use Plack::Middleware::Static;
use Plack::Middleware::ConditionalGET;
use Plack::Middleware::ETag;
use Plack::Middleware::Header;
use Plack::Middleware::ProxyMap;
use Plack::Runner;

# use XXX;

my $layout_file = 'cache/layout.html';

sub app {
    my $self = shift;

    open LAYOUT, $layout_file or die "Can't open '$layout_file'";
    my $layout = do {local $/; <LAYOUT>};
    close LAYOUT or die;

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
    if ($self->config->proxymap) {
        $app = Plack::Middleware::ProxyMap->wrap(
            $app,
            proxymap => $self->config->proxymap,
        );
    }
    return $app;
}

sub run {
    my $self = shift;
    my @args = @_;
    my $runner = Plack::Runner->new;
    $runner->parse_options(@args);
    $runner->run($self->app);
}

1;
