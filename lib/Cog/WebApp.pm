package Cog::WebApp;
use Mouse;
extends 'Cog::Plugin';

use constant index_file => '';
use constant plugins => [];
use constant site_navigation => [];
use constant url_map => [];
use constant js_files => [qw(
    jquery-1.4.4.min.js
    jquery.cookie.js
    jemplate.js
    separator.js
    cog.js
    config.js
    url-map.js
    start.js
)];
use constant css_files => [qw(
    layout.css
    page-list.css
    page-display.css
)];
use constant image_files => [];
use constant template_files => [];
use constant runner_class => 'Cog::WebApp::Runner';

package Cog::WebApp::Runner;
use Mouse;
use Plack::Middleware::Static;
use Plack::Middleware::ConditionalGET;
use Plack::Middleware::ETag;
use Plack::Middleware::Header;
use Plack::Runner;

use XXX;

has config => (is => 'ro', required => 1);

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
