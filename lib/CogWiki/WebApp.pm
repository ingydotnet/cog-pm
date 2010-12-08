package CogWiki::WebApp;
use Mouse;
use Plack::Response;
use Plack::Middleware::Static;
use Plack::Middleware::Debug;
use Plack::Runner;

use CogWiki::Store;
use CogWiki::Page;

use Template::Toolkit::Simple;
use IO::All;

use XXX;

has config => (is => 'ro', required => 1);

sub app {
    my $self = shift;

    throw Error "CogWiki is not set up"
        unless $self->config->is_ready;

    my $app = sub {
        my $e = shift;
        my $list = [
            sub { m!^/view/! } =>
                sub { $self->view(@_) },
            sub { $_ ne '/' } =>
                sub {
                    my $r = Plack::Response->new;
                    $r->redirect('/');
                    $r->finalize();
                },
            sub { 1 } =>
                sub { $self->index(@_) },
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

sub view {
    my $self = shift;
    my $env = shift;
    my $name = $env->{PATH_INFO};
    $name =~ s!^/view/!!;
    $name =~ s!/.*!!;
    $name =~ s!-.*!!;
    return unless $name;
    if ($name =~ /^home$/i) {
        $name = $self->config->home_page_id || return;
    }
    my $html_cache = "cache/view/$name";
    return unless -e $html_cache;
    my $data = {%{$self->config}};
    $data->{page_html} = io($html_cache)->all;
    $data->{view}{type} = 'view';
    my $html = tt
        ->path(['template/'])
        ->data($data)
        ->post_chomp
        ->render('view.html.tt');
    return [ 200, [ 'Content-Type' => 'text/html' ], [ $html ] ];
}

sub index {
    my $self = shift;

    # TODO Get pages objects for CogWiki::Store

    my $pages = [];
    for my $file (io('..')->all_files) {
        next if $file->filename =~ /^\./;
        my $page = CogWiki::Page->from_text($file->all);
        push @$pages, $page;
    }
    @$pages = sort {
        $b->time <=> $a->time or
        lc($a->title) cmp lc($b->title)
    } @$pages;
    my $data = {%{$self->config}};
    $data->{pages} = $pages;
    $data->{view}{type} = 'index';

    my $html = tt
        ->path(['template/'])
        ->data($data)
        ->post_chomp
        ->render('index.html.tt');

    return [ 200, [ 'Content-Type' => 'text/html' ], [ $html ] ];
}

1;
