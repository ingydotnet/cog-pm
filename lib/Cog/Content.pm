package Cog::Content;
use Mouse;
extends 'Cog::Base';
use IO::All;

use XXX;

sub all_files {
    my $self = shift;
    my $root = $self->config->content_root;
    my $paths = [ map {chomp; $_} `find $root -name *.cog` ];
    return $paths;
}

sub node_from_path {
    my $self = shift;
    my $path = shift;
    my $text = io($path)->all;
    my ($type) = ($text =~/^Type:\s+(\w+)$/mg)
        or die "$path has no Type";
    my $node_class = $self->store->node_class_map->{$type}
        or die;
    return $node_class->from_text($text);
}

1;
