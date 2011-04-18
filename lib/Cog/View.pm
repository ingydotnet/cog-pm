package Cog::View;
use Mouse;
extends 'Cog::Base';

use IO::All;

has root => (is => 'ro', default => 'view');
has views => ( is => 'ro', default => sub {+{}} );

sub BUILD {
    my $self = shift;
    mkdir $self->root;
    mkdir $self->root . "/tag";
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

    return $blob;
}

sub update_page_json {
    my ($self, $id, $blob) = @_;
    $self->views->{"$id"} = $blob;
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
        my $view = $self->views->{$name};
        $view = [ sort { $b->{Time} <=> $a->{Time} } @$view ]
            if $name eq 'page-list';
        io($self->root . "/$name.json")
            ->print($self->json->encode($view));
    }
    $self->clear;
}

sub clear {
    my $self = shift;
    $self->{views} = {};
}

1;
