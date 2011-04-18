package Cog::Content;
use Mouse;
extends 'Cog::Base';
use IO::All;

# use XXX;

has last_user => ( is => 'rw' );

sub update {
    my ($self, $node, $diff) = @_;

    my $new_text = $node->to_text;
    io($self->content_pointer($node))->print($new_text);

    $self->last_user($node->User);
}

sub flush {
    my $self = shift;
    $self->git_commit();
}

sub content_pointer {
    my $self = shift;
    my $node = shift;
#     my $content_root = $self->config->content_root;
    my $content_root = '.';
    my $id = $node->Short;
    my $type = $node->Type or die;
    my $title = $node->Title or die;
    $title =~ s/[^-.,A-Za-z0-9]+/_/g;
    $title =~ s/^_?(.*?)_?$/$1/g;
    $title ||= '_';
    return "$content_root/$type/$title--$id.cog";
}

sub cog_files {
    my $self = shift;
    my $root = $self->config->content_root;
    my $files = [
        map {
            chomp;
            $_;
        } `find $root -name *.cog`
    ];
    return $files;
}

sub dead_cog_files {
    my $self = shift;
    return [];
}

sub node_from_reference {
    my $self = shift;
    my $reference = shift;
    my $text = io($reference)->all;
    my ($type) = ($text =~/^Type:\s+(\w+)$/mg)
        or die "$reference has no Type";
    my $node_class = $self->store->schema_map->{$type}->node_class
        or die;
    return $node_class->from_text($text);
}

sub git_commit {
    my $self = shift;
    my $root = $self->config->content_root;
    my $user = $self->last_user;
    my $email = "$user\@example.com";
    local $ENV{GIT_AUTHOR_NAME} = $user;
    local $ENV{GIT_COMMITTER_NAME} = $user;
    local $ENV{GIT_AUTHOR_EMAIL} = $email;
    local $ENV{GIT_COMMITTER_EMAIL} = $email;
    my $msg = "updated by Cog web editor";
    my $cmd = "(cd $root; git add .; git commit -m '$msg')";
    system($cmd) == 0
        or die "Failed to commit change to git repo.";
}

1;
