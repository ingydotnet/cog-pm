# TODO:
# - Generate a Makefile to bring everything up to date
#   - Use tt with Makefile.tt template
package Cog::Maker;
use Mouse;
extends 'Cog::Base';

# use XXX;

use Template::Toolkit::Simple;
use IO::All;
use IPC::Run;
use Pod::Simple::HTML;

sub make {
    my $self = shift;
    $self->make_config_js();
    $self->make_url_map_js();
    $self->make_all_js();
    $self->make_all_css();
    $self->make_index_html;
    $self->make_store();
}

sub make_config_js {
    my $self = shift;
    my $config_path = $self->app->config_file;
    my $data = {
        json => $self->json->encode(YAML::XS::LoadFile($config_path)),
    };
    my $javascript = tt()
        ->path(['template/'])
        ->data($data)
        ->post_chomp
        ->render('config.js.tt');
    io('static/config.js')->print($javascript);
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
    io('static/url-map.js')->print($javascript);
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

    system("(cd $js; make)") == 0 or die;
    # TODO - Make fingerprint file here instead of Makefile
    my ($file) = glob("$js/all-*.js") or die;
    $file =~ s!.*/!!;
    $self->config->all_js_file($file);
}

sub make_all_css {
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
    my ($file) = glob("$css/all-*.css") or die;
    $file =~ s!.*/!!;
    $self->config->all_css_file($file);
}

sub make_index_html {
    my $self = shift;
    my $data = +{%{$self->config}};
    my $html = tt()
        ->path(['template/'])
        ->data($data)
        ->post_chomp
        ->render('index.html.tt');
    io('static/index.html')->print($html);
}

sub make_store {
    my $self = shift;
    if (not $self->store->exists) {
        $self->store->init();
        $self->store->import_files($self->content->cog_files);
        $self->store->reserve_keys($self->content->dead_cog_files);
    }
}

sub make_clean {
    my $self = shift;
    my $app_root = $self->config->app_root
        or die "app_root not available";
    $app_root =~ m!/!
        or die "app_root not absolute";
    for my $dir (
        "$app_root/static",
        "$app_root/template",
        "$app_root/view",
        $self->store->root,
    ) {
        if (-e $dir) {
            my $cmd = "rm -fr $dir";
            system($cmd) == 0
                or die "'$cmd' failed";
        }
    }
}

1;
