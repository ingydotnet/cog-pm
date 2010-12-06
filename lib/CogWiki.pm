package CogWiki;
use 5.008003;
use Mouse;
our $VERSION = '0.01';

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
