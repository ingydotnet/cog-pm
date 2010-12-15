package CogWiki::Maker;
use Mouse;

use CogWiki::Page;

# NOTE This module should generate a Makefile to do all this work.

use Template::Toolkit::Simple;
use IO::All;
use IPC::Run;
use JSON;
use Time::Duration;

has config => ('is' => 'ro', required => 1);
has store => ('is' => 'ro', required => 1);
has json => ('is' => 'ro', builder => sub {
    my $json = JSON->new;
    $json->allow_blessed;
    $json->convert_blessed;
    return $json;
});

sub make {
    my $self = shift;
    $self->config->chdir_root();

    io('cache')->mkdir;
    my $data = +{%{$self->config}};
    my $html = tt()
        ->path(['template/'])
        ->data($data)
        ->post_chomp
        ->render('layout.html.tt');
    io('cache/layout.html')->print($html);

    $data = {
        json => $self->json->encode(YAML::XS::LoadFile("config.yaml")),
    };
    my $javascript = tt()
        ->path(['template/'])
        ->data($data)
        ->post_chomp
        ->render('config.js.tt');
    io('cache/config.js')->print($javascript);

    my $time = time;
    my $news = [];
    my $blobs = {};

    $self->store->delete_tag_index; # XXX Temporary solution until can do smarter
    for my $page_file (io($self->config->content_root)->all_files) {
        next if $page_file->filename =~ /^\./;
        my $page = CogWiki::Page->from_text($page_file->all);
        my $id = $page->short or next;

        $self->store->index_tag($_, $id)
            for @{$page->tag};

        my $blob = {
            id => $id,
            rev => $page->rev,
            title => $page->title,
            time => $page->time,
            user => $page->user,
            size => length($page->content),
            color => $page->color,
            # XXX Needs to be client side
            duration => $page->duration,
        };
        push @$news, $blob;
        $blobs->{$id} = $blob;

        $self->make_page_html($page, $page_file);

        delete $page->{content};
        io("cache/$id.json")->print($self->json->encode({%$page}));
    }
    io("cache/news.json")->print($self->json->encode($news));

    $self->make_tag_cloud($blobs);
    $self->make_js();
    $self->make_css();
}

sub make_tag_cloud {
    my $self = shift;
    my $blobs = shift;
    my $hash = {};
    my $index = {};
    for my $tag (@{$self->store->all_tags}) {
        my $ids = $self->store->indexed_tag($tag);
        $hash->{$tag} = scalar @$ids;
        my $tagged = [ map $blobs->{$_}, @$ids ];
        io("cache/tag/$tag.json")->assert->print($self->json->encode($tagged));
    }
    io("cache/tag-cloud.json")->print($self->json->encode($hash));

}

sub make_page_html {
    my $self = shift;
    my $page = shift;
    my $page_file = shift;
    my $id = $page->short;
    my $html_filename = "cache/$id.html";

    return if -e $html_filename and -M $html_filename < -M $page_file->name;

    my ($in, $out, $err) = ($page->content, '', '');

    my @cmd = qw(asciidoc -s -);
    
    print $page_file->filename . " -> $html_filename\n";
    IPC::Run::run(\@cmd, \$in, \$out, \$err, IPC::Run::timeout(10));

    io($html_filename)->assert->print($out);
}

sub make_js {
    my $self = shift;
    my $root = $self->config->root_dir;
    my $js = "$root/static/js";
    if (-e "$js/Makefile") {
        system("(cd $js; make)") == 0 or die;
    }
}

sub make_css {
    my $self = shift;
    my $root = $self->config->root_dir;
    my $css = "$root/static/css";
    if (-e "$css/Makefile") {
        system("(cd $css; make)") == 0 or die;
    }
}

1;
