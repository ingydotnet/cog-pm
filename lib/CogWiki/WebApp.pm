package CogWiki::WebApp;
use Mouse;
use Plack::Response;
use Plack::Middleware::Static;
use Plack::Middleware::Debug;
use Plack::Runner;

use CogWiki::Store;
use CogWiki::Page;

use IO::All;

# use XXX;

has config => (is => 'ro', required => 1);

sub app {
    my $self = shift;

    throw Error "CogWiki is not properly set up"
        unless $self->config->is_ready;

    my $app = sub {
        my $e = shift;
        my $list = [
            # XXX Paths need to come from config
            sub { m!^/(story|news|home)/! } =>
                sub { $self->layout(@_) },
            sub { $_ ne '/' } =>
                sub {
                    my $r = Plack::Response->new;
                    $r->redirect('/');
                    $r->finalize();
                },
            sub { 1 } =>
                sub { $self->layout(@_) },
        ];
        for (my $i = 0; $i < @$list; $i += 2) {
            $_ = $e->{PATH_INFO};
            if ($list-> [$i]->()) {
                my $result = $list->[$i + 1]->($e);
                return $result if $result;
            }
        }
    };

#     $app = Plack::Middleware::Debug->wrap($app);
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

sub layout {
    my $self = shift;
    my $html = io('cache/index.html')->all;
    return [ 200, [ 'Content-Type' => 'text/html' ], [ $html ] ];
}

1;
