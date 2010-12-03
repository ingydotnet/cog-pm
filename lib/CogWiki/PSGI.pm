package CogWiki::PSGI;
use Mouse;
use Plack::Response;
use Plack::Middleware::Static;
use Plack::Middleware::Debug;
use Plack::Runner;

sub app {
    my $class = shift;

    my $webapp = CogWiki::App->new();
    throw Error "CogWiki is not set up"
        unless $webapp->config->is_wiki;

    my $app = sub {
        my $e = shift;
        my $list = [
            sub { m!^/view/! } =>
                sub { CogWiki->view(@_) },
            sub { $_ ne '/' } =>
                sub {
                    my $r = Plack::Response->new;
                    $r->redirect('/');
                    $r->finalize();
                },
            sub { 1 } =>
                sub { CogWiki->index(@_) },
        ];
        for (my $i = 0; $i < @$list; $i += 2) {
            $_ = $e->{PATH_INFO};
            if ($list-> [$i]->()) {
                my $result = $list->[$i + 1]->($e);
                return $result if $result;
            }
        }
    };

    $app = Plack::Middleware::Debug->wrap($app);
    $app = Plack::Middleware::Static->wrap($app, path => qr{^/static/}, root => './');
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
