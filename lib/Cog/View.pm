package Cog::View;
use Mouse;
extends 'Cog::Base';

use IO::All;

use XXX;

has root => (is => 'ro', default => 'view');
has views => ( is => 'ro', default => sub {+{}} );

sub BUILD {
    my $self = shift;
    mkdir $self->root;
    return $self;
}

sub get {
    # read from view/ into view map
}

sub put {
    # write from view map into view/
    # delete from view map
}

sub update {
    my $self = shift;
    my $node = shift;
    my $diff = shift;

    my $id = $node->Short;

    my $blob = {
        %$node,
        Id => $id,
        Title => $node->Title,
    };
    delete @{$blob}{qw(Name)};

    $self->update_page_json($id, $blob);
    $self->update_page_html($id, $node, $diff);
    $self->update_page_list($blob);
}

sub update_page_json {
    my ($self, $id, $blob) = @_;
    io($self->root . "/$id.json")->print($self->json->encode($blob));
}

sub update_page_html {
    my ($self, $id, $node, $diff) = @_;
    if (grep { $_->[1] =~ /^(Body|Format)$/ } @$diff) {
        my $html = $self->maker->markup_to_html($node->Body, $node->Format);
        io($self->root . "/$id.html")->print($html);
    }
}

sub update_page_list {
    my ($self, $blob) = @_;
    my $list = $self->views->{'page-list'} ||= [];
    push @$list, $blob;
}

sub flush {
    my $self = shift;
    for my $name (keys %{$self->views}) {
        my $view = delete $self->views->{$name};
        if ($name eq 'page-list') {
            $view = [
                sort { $b->{Time} <=> $a->{Time} } @$view
            ];
        }
        io($self->root . "/$name.json")
            ->print($self->json->encode($view));
    }
}

1;

__END__
sub all_tags {
    my ($self, $page) = @_;
    return (
        @{$page->Tag},
        ($page->Type || ()),
        ($page->iteration || ()),
        ($page->contact || ()),
        ($page->project || ()),
        ($page->status || ()),
    );
}

sub make_cache {
    my $self = shift;
    io('cache')->mkdir;

    my $time = time;
    my $page_list = [];
    my $blobs = {};

    for my $page_file ($self->all_files) {
#         my $page = $self->config->classes->{node}->from_text($page_file->all);
#         my $id = $page->Short or next;
#         io($self->store->root . "/node/$id")->assert->touch;

        for my $Name (@{$page->Name}) {
            my $name = $self->store->index_name($Name, $id);
            io->file("cache/name/$name.txt")->assert->print($id);
        }

        $self->store->index_tag($_, $id)
            for $self->all_tags($page);
            
        my $blob = {
            %$page,
            Id => $id,
            Title => $page->Title,
        };
        delete $blob->{Name};
        push @$page_list, $blob;
        $blobs->{$id} = $blob;

        $self->make_page_html($page, $page_file);

        delete $page->{content};
        io("cache/$id.json")->print($self->json->encode($blob));
    }
    io("cache/page-list.json")->print($self->json->encode($page_list));
    $self->make_tag_cloud($blobs);
}

sub make_tag_cloud {
    my $self = shift;
    my $blobs = shift;
    my $list = [];
    my $tags = {};
    for my $tag (sort {lc($a) cmp lc($b)} @{$self->store->all_tags}) {
        my $ids = $self->store->indexed_tag($tag);
        my $t = 0; for (@$ids) { if ((my $t1 = $blobs->{$_}{Time} || 0) > $t) { $t = $t1 } }
        push @$list, [$tag, scalar(@$ids), "${t}000"];
        my $tagged = [ map $blobs->{$_}, @$ids ];
        io("view/tag/$tag.json")->assert->print($self->json->encode($tagged));
        $tags->{$tag} = 1;
    }
    io("view/tag-cloud.json")->print($self->json->encode($list));
    io("view/tag-list.json")->print($self->json->encode([sort keys %$tags]));
}
