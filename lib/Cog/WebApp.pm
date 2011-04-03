package Cog::WebApp;
use Mouse;
extends 'Cog::Base';

# use XXX;

has env => ( is => 'rw' );

use constant index_file => '';
use constant plugins => [];
use constant site_navigation => [];
use constant url_map => [];
use constant post_map => [];
use constant js_files => [qw(
    jquery-1.4.4.js
    jquery.json-2.2.js
    jquery.cookie.js
    jquery.jemplate.js
    jemplate.js
    cog.js
    config.js
    url-map.js
    fixups.js
)];
use constant css_files => [qw(
    layout.css
    page-list.css
    page-display.css
)];
use constant image_files => [];
use constant template_files => [];
use constant runner_class => 'Cog::WebApp::Runner';

sub web_app {
    my $self = shift;
    my $index_file = 'static/index.html';
    open INDEX, $index_file or die "Can't open '$index_file'";
    my $html = do {local $/; <INDEX>};
    close INDEX or die;

    my $time = scalar(gmtime);
    $time .= ' GMT' unless $time =~ /GMT/;
    return sub {
        my $env = shift;
        return $env->{REQUEST_METHOD} eq 'POST'
            ? $self->handle_post($env)
            : [
                200, [
                    'Content-Type' => 'text/html',
                    'Last-Modified' => $time,
                ], [$html]
            ];
    };
}

sub handle_post {
    # Call handler based on url
    # Return results or OK
    my $self = shift;
    $self->env(shift);
    $self->read_json;
    my $path = $self->env->{PATH_INFO};
    my $post_map = $self->config->post_map;
    my ($regexp, $action, @args, @captures);
    for my $entry (@$post_map) {
        ($regexp, $action, @args) = @$entry;
        if ($path =~ /^$regexp$/) {
            @captures = ('', $1, $2, $3, $4, $5);
            last;
        }
        undef $action;
    }
    return [501, [], ["Invalid POST request: '$path'"]] unless $action;
    @args = map {s/\$(\d+)/$captures[$1]/ge; ($_)} @args;
    my $method = "handle_$action";
    my $result = eval { $self->$method(@args) };
    if ($@) {
        warn $@;
        return [500, [], [ $@ ]];
    }
    $result = 'OK' unless defined $result;
    if (ref($result) eq 'ARRAY') {
        return $result;
    }
    elsif (ref($result) eq 'HASH') {
        return [
            200,
            [ 'Content-Type' => 'application/json' ],
            [ $self->json->encode($result) ]
        ];
    }
    else {
        return [ 200, [ 'Content-Type' => 'text/plain' ], [ $result ] ];
    }
}

sub read_json {
    my $self = shift;
    my $env = $self->env;
    return unless
        $env->{CONTENT_TYPE} =~ m!application/json! and
        $env->{CONTENT_LENGTH};
    my $json = do { my $io = $env->{'psgi.input'}; local $/; <$io> };
    $env->{post_data} = $self->json->decode($json);
}

1;
