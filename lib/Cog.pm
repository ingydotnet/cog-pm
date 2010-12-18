package Cog;
use 5.008003;
use Mouse;
our $VERSION = '0.02';

sub url_map {
    [
#         ['/' => 'cog_welcome']
    ];
}

sub js_files {
    [qw(
        jquery-1.4.4.min.js
        separator.js
        jemplate.js
        separator.js
        cog.js
        config.js
        url-map.js
        start.js

        sidepanel.js
        tag-cloud.js
    )]
}

sub css_files {
    [qw(
        layout.css
        page-list.css
        story.css
        postit.css
        tag-cloud.css
    )];
}

sub image_files {
    [qw(
        tile.gif
    )];
}

sub template_files {
    [qw(
        config.js.tt
        js-mf.mk.tt
        css-mf.mk.tt
        layout.html.tt
        page-list.html.tt
        postit.html.tt
        sidepanel.html.tt
        story.html.tt
        tag-cloud.html.tt
        404.html.tt
    )];
}

1;

=encoding utf8

=head1 NAME

Cog - The Cog Information Access Framework

=head1 SYNOPSIS

    > cd content/dir
    > cog init
    > edit .cog/config.yaml
    > cog make
    > cog start

=head1 DESCRIPTION

Cog lets you turn any directory on your computer into an interactive
appication, like a website or a wiki.

Cog installs a command line utility called C<cog>. This command can be
used to create and update your application.

=head1 DOCUMENTATION

See L<Cog::Manual> for more information.

=head1 AUTHOR

Ingy döt Net <ingy@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2010. Ingy döt Net.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
