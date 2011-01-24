package Cog::WebApp::Runner;
use Mouse;
extends 'Cog::Base';

use Plack::Middleware::Static;
use Plack::Middleware::ConditionalGET;
use Plack::Middleware::ETag;
use Plack::Middleware::Header;
use Plack::Runner;

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
    if ($self->config->proxy_map) {
        $app = Cog::WebApp::Middleware->wrap(
            $app,
            proxy_map => $self->config->proxy_map,
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

package Cog::WebApp::Middleware;
use parent 'Plack::Middleware';

use Plack::App::Proxy;

use XXX -with => 'YAML::XS';

sub call {
    my $self = shift;
    my $env = shift;
    my $map = $self->{proxy_map};
    for my $type (keys %$map) {
        my ($path_prefix, $remote, $headers) =
            @{$map->{$type}}{qw(path_prefix remote headers)};
        $headers ||= [];
        my $path = $env->{PATH_INFO};
        if ($path =~ s/^\Q$path_prefix\E//) {
            my $url = "$remote$path";
            return Plack::App::Proxy->new(
                remote => $url,
                preserve_host_header => 1,
            )->(+{%$env, %$headers});
        }
    }
    return $self->app->($env);
}

1;
