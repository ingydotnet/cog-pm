package Cog::FileBrowser;
use Mouse;
extends 'Cog::App';

use constant webapp => 'Cog::FileBrowser::WebApp';

package Cog::FileBrowser::WebApp;
use Mouse;
extends 'Cog::WebApp';

use constant index_file => 'index.html';

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
        jquery.cookie.js
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

=encoding utf8;

=head1 NAME

Cog::FileBrowser -- Sample App/WebApp Built on Cog Framework

=head1 SYNOPSIS

    > cog init Cog::FileBrowser
    > cog update
    > cog make
    > cog start

=head1 AUTHOR

Ingy döt Net <ingy@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2011. Ingy döt Net.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
