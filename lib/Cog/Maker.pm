package Cog::Maker;
use Mouse;
extends 'Cog::Base';

# NOTE This module should generate a Makefile to do all this work.

use Template::Toolkit::Simple;
use IO::All;
use IPC::Run;
use JSON;
use Time::Duration;
use Pod::Simple::HTML;

# use XXX;

has json => ('is' => 'ro', builder => sub {
    my $json = JSON->new;
    $json->allow_blessed;
    $json->convert_blessed;
    return $json;
});

# XXX Move this to CogWiki
sub make {
    my $self = shift;
    $self->config->chdir_root();
    $self->make_cache;
    $self->make_layout;
    $self->make_config_js();
    $self->make_url_map_js();
    $self->make_all_js();
    $self->make_css();
}

sub make_cache {
    my $self = shift;
    io('cache')->mkdir;
}

sub make_layout {
    my $self = shift;
    my $data = +{%{$self->config}};
    my $html = tt()
        ->path(['template/'])
        ->data($data)
        ->post_chomp
        ->render('layout.html.tt');
    io('cache/layout.html')->print($html);
}

sub all_tags {
    my ($self, $page) = @_;
    return @{$page->Tag};
}

sub make_config_js {
    my $self = shift;
    my $config_path = $self->config->app_root . '/config.yaml';
    my $data = {
        json => $self->json->encode(YAML::XS::LoadFile($config_path)),
    };
    my $javascript = tt()
        ->path(['template/'])
        ->data($data)
        ->post_chomp
        ->render('config.js.tt');
    io('cache/config.js')->print($javascript);
}

sub make_url_map_js {
    my $self = shift;
    my $data = {
        json => $self->json->encode($self->config->url_map),
    };
    my $javascript = tt()
        ->path(['template/'])
        ->data($data)
        ->post_chomp
        ->render('url-map.js.tt');
    io('cache/url-map.js')->print($javascript);
}

sub make_tag_cloud {
    my $self = shift;
    my $blobs = shift;
    my $list = [];
    my $tags = {};
    for my $tag (sort {lc($a) cmp lc($b)} @{$self->config->store->all_tags}) {
        my $ids = $self->config->store->indexed_tag($tag);
        my $t = 0; for (@$ids) { if ((my $t1 = $blobs->{$_}{Time}) > $t) { $t = $t1 } }
        push @$list, [$tag, scalar(@$ids), "${t}000"];
        my $tagged = [ map $blobs->{$_}, @$ids ];
        io("cache/tag/$tag.json")->assert->print($self->json->encode($tagged));
        $tags->{$tag} = 1;
    }
    io("cache/tag-cloud.json")->print($self->json->encode($list));
    io("cache/tag-list.json")->print($self->json->encode([sort keys %$tags]));
}

sub make_all_js {
    my $self = shift;
    my $root = $self->config->app_root;
    my $js = "$root/static/js";

    my $data = {list => join(' ', @{$self->config->js_files})};
    my $makefile = tt()
        ->path(['template/'])
        ->data($data)
        ->post_chomp
        ->render('js-mf.mk.tt');
    io("$js/Makefile")->print($makefile);

    system("(cd $js; make all.js)") == 0 or die;
}

sub make_css {
    my $self = shift;
    my $root = $self->config->app_root;
    my $css = "$root/static/css";

    my $data = {list => join(' ', @{$self->config->css_files})};
    my $makefile = tt()
        ->path(['template/'])
        ->data($data)
        ->post_chomp
        ->render('css-mf.mk.tt');
    io("$css/Makefile")->print($makefile);

    system("(cd $css; make)") == 0 or die;
}

1;
