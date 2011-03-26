package Cog::View;
use Mouse;
extends 'Cog::Base';

use IO::All;

# use XXX;

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
    $self->update_tag_cloud($blob);
    $self->update_story_tasks($blob);
}

sub update_story_tasks {
    my ($self, $task) = @_;
    return unless $task->{Type} eq 'task';
    my $story_id = $task->{story}
        or return;
    $story_id =~ s/^\*(\w{4})$/$1/
        or die "$story_id is invalid story_id pointer";
    my $story = $self->views->{$story_id}
        or return;
    return unless $story->{Type} eq 'story';
    my $tasks = $story->{_tasks} ||= [];
    push @$tasks, $task->{Id};
}

sub update_tag_cloud {
    my ($self, $blob) = @_;
    my $time = $blob->{Time} * 1000;
    my $cloud = $self->views->{'tag-cloud'} ||= {};
    for my $name (qw(Type contact iteration department)) {
        my $tag = $blob->{$name} or next;
        $self->add_tag($cloud, $tag, $time, $blob);
    }
    for my $tag (@{$blob->{Tag} || []}) {
        $self->add_tag($cloud, $tag, $time, $blob);
    }
}

sub add_tag {
    my ($self, $cloud, $tag, $time, $blob) = @_;
    $cloud->{$tag} ||= [$tag, 0, 0];
    $cloud->{$tag}[1]++;
    $cloud->{$tag}[2] = $time
        if $time > $cloud->{$tag}[2];
    my $group = $self->views->{"tag/$tag"} ||= [];
    push @$group, $blob;
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
        $self->compile_hours($view)
            if $name =~ /^[A-Z2-9]{4}$/ and $view->{_tasks};
        $view = [ sort { $b->{Time} <=> $a->{Time} } @$view ]
            if $name eq 'page-list';
        $view = [ values %$view ]
            if $name eq 'tag-cloud';
        io($self->root . "/$name.json")
            ->print($self->json->encode($view));
    }
    $self->clear;
}

sub compile_hours {
    my ($self, $story) = @_;
    my ($estimate, $worked, $remain) = (0, 0, 0);
    for my $id (@{$story->{_tasks}}) {
        my $task = $self->views->{$id};
        $estimate += $task->{estimate} || 0;
        $worked += $task->{worked} || 0;
        $remain += $task->{remain} || 0;
    }
    $story->{estimate} = $estimate;
    $story->{worked} = $worked;
    $story->{remain} = $remain;
}

sub clear {
    my $self = shift;
    $self->{views} = {};
}

1;
