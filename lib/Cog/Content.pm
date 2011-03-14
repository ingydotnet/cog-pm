package Cog::Content;
use Mouse;
extends 'Cog::Base';
use IO::All;

use XXX;

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
    my ($self, $root, $file, $page) = @_;
    my $user = $page->{User};
    my $email = "$user\@strategicdata.com.au";
    local $ENV{GIT_AUTHOR_NAME} = $user;
    local $ENV{GIT_COMMITTER_NAME} = $user;
    local $ENV{GIT_AUTHOR_EMAIL} = $email;
    local $ENV{GIT_COMMITTER_EMAIL} = $email;
    my $msg = "$file updated by SSB web editor";
    my $cmd = "(cd $root; git add $file; git commit -m '$msg')";
    system($cmd) == 0
        or die "Failed to commit change to git repo.";
}

1;
