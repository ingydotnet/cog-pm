package Cog;
use 5.008003;
use Mouse;

our $VERSION = '0.02';

extends 'Cog::Plugin';

use constant index_file => 'layout.html';

sub site_navigation {
    [
        ['Home' => '/home/'],
        ['Files' => '/files/'],
        ['Tags' => '/tags/'],
    ]
}

sub url_map {
    [
        ['/' => 'redirect', ('/home/')],
        ['/home/' => 'about_cog'],
        ['/files/' => 'files_list'],
        ['/tags/' => 'tags_list'],
    ];
}

sub js_files {
    [qw(
        jquery-1.4.4.min.js
        jemplate.js
        separator.js
        cog.js
        config.js
        url-map.js
        start.js
    )]
}

sub css_files {
    [qw(
        layout.css
        page-list.css
        page-display.css
    )];
}

sub image_files {
    [qw(
        tile.gif
        cog.png
    )];
}

sub template_files {
    [qw(
        config.js.tt
        js-mf.mk.tt
        css-mf.mk.tt

        layout.html.tt
        site-navigation.html.tt
        page-list.html.tt
        page-display.html.tt
        tag-list.html.tt
        404.html.tt
    )];
}

1;

=encoding utf8

=head1 NAME

Cog - The Cog Information Application Framework

=head1 SYNOPSIS

    > cd content/dir
    > cog init
    > cog make
    > cog start

=head1 STATUS

This software is pre-alpha. Don't use it for anything serious yet.

=head1 DESCRIPTION

Cog lets you turn any directory on your computer into an interactive
application, like a website or a wiki.

This module installs a command line utility called C<cog>. This command
can be used to create and update your application.

=head1 DOCUMENTATION

See L<Cog::Manual> for more information.

=head1 KUDOS

Many thanks to the good people of Strategic Data in Melbourne Victoria
Australia, for supporting me and this project. \o/

=head1 AUTHOR

Ingy döt Net <ingy@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2010. Ingy döt Net.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
