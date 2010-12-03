package CogWiki;
use 5.008003;
use Mouse;
use Template::Toolkit::Simple;
use IO::All;
use YAML::XS;
use XXX -with => 'YAML::XS';

our $VERSION = '0.01';

my $config = -f 'config.yaml' ? YAML::XS::LoadFile('config.yaml') : {};

sub view {
    my $class = shift;
    my $env = shift;
    my $name = $env->{PATH_INFO};
    $name =~ s!^/view/!!;
    $name =~ s!/.*!!;
    $name =~ s!-.*!!;
    return unless $name;
    if ($name =~ /^home$/i) {
        $name = $config->{home_page_id} || return;
    }
    my $html_cache = "cache/view/$name";
    return unless -e $html_cache;
    $config->{page_html} = io($html_cache)->all;
    $config->{view}{type} = 'view';
    my $html = tt
        ->path(['template/'])
        ->data($config)
        ->post_chomp
        ->render('view.html.tt');
    return [ 200, [ 'Content-Type' => 'text/html' ], [ $html ] ];
}

sub index {
    my $class = shift;

    my $pages = [];
    for my $file (io('..')->all_files) {
        next if $file->filename =~ /^\./;
        my $page = CogWiki::Page->from_text($file->all);
        push @$pages, $page;
    }
    @$pages = sort {
        $b->time <=> $a->time or
        lc($a->title) cmp lc($b->title)
    } @$pages;
    $config->{pages} = $pages;
    $config->{view}{type} = 'index';

    my $html = tt
        ->path(['template/'])
        ->data($config)
        ->post_chomp
        ->render('index.html.tt');

    return [ 200, [ 'Content-Type' => 'text/html' ], [ $html ] ];
}

package CogWiki::Edit;
use IO::All;

sub run {
    my $class = shift;
    my $filename = shift or die "No filename supplied";
    die "Bad filename" if $filename =~ m/[\n\\]/;
    die "Too many args" if @_;

    my $oldtext = -e $filename ? io( $filename )->all : '';
    my $oldpage = CogWiki::Page->from_text($oldtext);
    my $rev = $oldpage->rev;

    system("vim $filename") == 0 or die;

    my $newtext = -e $filename ? io( $filename )->all : '';
#     my $newpage = CogWiki::Page->from_text($newtext);
    $rev++;
    $newtext =~ s/^Rev: +.*\n/Rev: $rev\n/m or die;
    my $time = time;
    $newtext =~ s/^Time: +.*\n/Time: $time\n/m or die;
    io($filename)->print($newtext);

    system("generate_pages") == 0 or die;
}

package CogWiki::Page;
use Mouse;
use Time::Duration;

has id => ( is => 'rw' );
has rev => ( is => 'rw' );
has time => ( is => 'rw' );
has user => ( is => 'rw' );
has name => ( is => 'rw', default => sub {[]} );
has tag => ( is => 'rw', default => sub {[]} );
has content => ( is => 'rw' );
has title => ( is => 'rw' );
has short => ( is => 'rw' );
has size => ( is => 'rw' );
has duration => ( is => 'rw' );

sub from_text {
    my $class = shift;
    my $text = shift;

    my %hash;
    my $head = ($text =~ s/\A((?:[\w\-]+:\ .*\n)+)(\n|\z)//) ? $1 : '';
    while ($head =~ s/\A(\w+): +(.*)\n//) {
        my $key = lc $1;
        my $value = $2;
        if ($key =~ /^(?:name|tag)$/) {
            $hash{$key} ||= [];
            push @{$hash{$key}}, $value;
        }
        else {
            $hash{$key} = $value;
        }
    }
    throw Error "Can't parse:\n$head" if $head;

    $hash{content} = $text;
    my $self = $class->new(%hash);
    $self->title($self->name->[0] || '???');
    my $short = $self->id;
    $short =~ s/-.*//;
    $self->short($short);
    $self->size(length $text);
    $self->duration(Time::Duration::duration(time - $self->time, 1));
    return $self;
}

sub to_text {
    my $self = shift;
    my %keys = map ($_, 1), keys %$self;
}

package CogWiki::Store;
use Mouse;

has root_dir => ( is => 'ro' );

sub BUILD {
    my $self = shift;
    my $root = $self->root_dir;
}

1;

=encoding utf8

=head1 NAME

CogWiki - Turn Anything into a Wiki

=head1 SYNOPSIS

    > cd content/dir
    > cogwiki init
    > edit .wiki/config.yaml
    > cogwiki make
    > cogwiki up

=head1 DESCRIPTION

CogWiki lets you turn any directory on your computer into a wiki. Every
file in the directory is a wiki page. All CogWiki files are put into a
C<.wiki/> subdirectory. CogWiki uses git for wiki history. If your
directory is already a git repo, CogWiki can use its GIT_DIR, or it can
set up its own. CogWiki is a Perl Plack program, so you can run it in
any web environment. The 'up' command will start a local web server that
you can use immediately (even offline).

CogWiki installs a command line utility called C<cogwiki>. This command
can be used to create and update the wiki. It can also act as a git
hook command.

=head1 DOCUMENTATION

See L<CogWiki::Manual> for more information.

=head1 AUTHOR

Ingy döt Net <ingy@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2010. Ingy döt Net.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
