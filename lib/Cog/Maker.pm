package Cog::Maker;
use Mouse;

# NOTE This module should generate a Makefile to do all this work.

use Template::Toolkit::Simple;
use IO::All;
use IPC::Run;
use JSON;
use Time::Duration;
use Pod::Simple::HTML;

use XXX;

has config => ('is' => 'ro', required => 1);
has store => ('is' => 'ro', required => 1);
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

    # Crea
    io('cache')->mkdir;
    my $data = +{%{$self->config}};
    my $html = tt()
        ->path(['template/'])
        ->data($data)
        ->post_chomp
        ->render('layout.html.tt');
    io('cache/layout.html')->print($html);

    $self->make_config_js();
    $self->make_url_map_js();

    my $time = time;
    my $page_list = [];
    my $blobs = {};

    $self->store->delete_tag_index; # XXX Temporary solution until can do smarter
    for my $page_file (io($self->config->content_root)->all_files) {
        next unless $page_file->filename =~ /\.cog$/;
        my $page = $self->config->classes->{page}->from_text($page_file->all);
        my $id = $page->Short or next;

        for my $Name (@{$page->Name}) {
            my $name = $self->store->index_name($Name, $id);
            io->file("cache/name/$name.txt")->assert->print($id);
        }

        $self->store->index_tag($_, $id)
            for $self->all_tags($page);
            
        my $blob = {
            %$page,
            Id => $id,
            Type => $page->Type,
            Title => $page->Title,
            Time => $page->Time,
            size => length($page->Content),
            duration => $page->duration,
        };
        delete $blob->{Content};
        delete $blob->{Name};
        push @$page_list, $blob;
        $blobs->{$id} = $blob;

        $self->make_page_html($page, $page_file);

        delete $page->{content};
        io("cache/$id.json")->print($self->json->encode($blob));
    }
    io("cache/page-list.json")->print($self->json->encode($page_list));

    $self->make_tag_cloud($blobs);
    $self->make_js();
    $self->make_css();
}

sub all_tags {
    my ($self, $page) = @_;
    return @{$page->Tag};
}

sub make_config_js {
    my $self = shift;
    my $data = {
        json => $self->json->encode(YAML::XS::LoadFile("config.yaml")),
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
    for my $tag (sort {lc($a) cmp lc($b)} @{$self->store->all_tags}) {
        my $ids = $self->store->indexed_tag($tag);
        my $t = 0; for (@$ids) { if ((my $t1 = $blobs->{$_}{Time}) > $t) { $t = $t1 } }
        push @$list, [$tag, scalar(@$ids), "${t}000"];
        my $tagged = [ map $blobs->{$_}, @$ids ];
        io("cache/tag/$tag.json")->assert->print($self->json->encode($tagged));
        $tags->{$tag} = 1;
    }
    io("cache/tag-cloud.json")->print($self->json->encode($list));
    io("cache/tag-list.json")->print($self->json->encode([sort keys %$tags]));
}

sub make_page_html {
    my $self = shift;
    my $page = shift;
    my $page_file = shift;
    my $id = $page->Short;
    my $html_filename = "cache/$id.html";

    return if -e $html_filename and -M $html_filename < -M $page_file->name;

    my $markup = $page->markup;

    my $method =
        $markup eq 'pod' ? 'make_pod_html' :
        $markup eq 'asc' ? 'make_asc_html' :
        $markup eq 'txt' ? 'make_txt_html' :
        'make_txt_html';

    my $html = $self->$method($page);

    print $page_file->filename . " -> $html_filename\n";
    io($html_filename)->assert->print($html);
}

sub make_txt_html {
    my $self = shift;
    my $page = shift;
    my $html = $page->Content;

    $html =~ s/&/&amp;/g;
    $html =~ s/</&lt;/g;
    $html =~ s/>/&gt;/g;

    $html = "<pre>$html</pre>\n";

    return $html;
}

sub make_asc_html {
    my $self = shift;
    my $page = shift;

    my ($in, $out, $err) = ($page->Content, '', '');
    my @cmd = qw(asciidoc -s -);
    IPC::Run::run(\@cmd, \$in, \$out, \$err, IPC::Run::timeout(30));

    return $out;
}

sub make_pod_html {
    my $self = shift;
    my $page = shift;

    my $html;
    my $pod = $page->Content;
    my $p = Pod::Simple::HTML->new;
    $p->output_string(\$html);
    $p->parse_string_document($pod);

    $html =~ s/.*!-- start doc -->(.*?)<!-- end doc --.*/$1/s or die;

    return $html;
}

sub make_js {
    my $self = shift;
    my $root = $self->config->root_dir;
    my $js = "$root/static/js";

    my $data = {list => join(' ', @{$self->config->js_files})};
    my $makefile = tt()
        ->path(['template/'])
        ->data($data)
        ->post_chomp
        ->render('js-mf.mk.tt');
    io("$js/Makefile")->print($makefile);

    system("(cd $js; make)") == 0 or die;
}

sub make_css {
    my $self = shift;
    my $root = $self->config->root_dir;
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
