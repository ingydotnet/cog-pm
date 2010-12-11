package CogWiki::Command;
use Mouse;
use Try::Tiny;
use Class::Throwable qw(Error);
use CogWiki::Config;
use IO::All;

has config => (is => 'ro', builder => sub {CogWiki::Config->new()});
has app => (is => 'ro', builder => '_app_builder');
has action => (is => 'ro');
has argv => (is => 'ro', default => sub {[]});

around BUILDARGS => sub {
    my ($orig, $class) = splice @_, 0, 2;
    $class->$orig($class->_parse_args(@_));
};

sub _app_builder {
    my $self = shift;
    require CogWiki::App;
    return CogWiki::App->new(config => $self->config);
}

sub run {
    my $self = shift;
    my $action = $self->action;
    my $method = "handle_$action";
    my ($object, $function);

    $function =
        ($object = $self)->can($method) ||
        ($object = $self->app)->can($method)
        or throw Error "'$action' is an invalid action\n";
    try {
        $function->($object, @{$self->argv});
    }
    catch {
        s/^Error : //;
        throw Error "'$action' failed:\n$_\n";
    };
    return 0;
}

sub handle_help {
    my $self = shift;
    print $self->usage;
}

sub usage {
    my $self = shift;
    return <<'...';
Usage: cogwiki command

Commands:
    init   - Make current directory into a CogWiki
    update - Update the wiki with the latest assets
    make   - Prepare the wiki content for the web
    up     - Start up a local wiki server
    down   - Stop the server

    bless file-name - Turn a text file into a wiki file
    edit name|id - Start an editor with the contents of the wiki page

See:
    `perldoc cogwiki` - Documentation on this command.
    `perldoc CogWiki::Manual` - Complete CogWiki documentation.
...
}

sub _parse_args {
    my $class = shift;
    my ($script, @argv) = @_;
    my $args = {};
    $script =~ s!.*/!!;
    if ($script =~ /^(pre-commit|post-commit)$/) {
        ($args->{action} = $script) =~ s/-/_/;
    }
    elsif ($script ne 'cogwiki') {
        throw Error "unexpected script name '$script'\n";
    }
    elsif (@argv and $argv[0] =~ /^\w+$/) {
        $args->{action} = shift @argv;
        $args->{argv} = [@argv];
    }
    elsif (not @argv) {
        $args->{action} = 'help';
    }
    else {
        use XXX;
        XXX @_;
    }
    return $args;
}

1;

=encoding utf8

=head1 NAME

CogWiki - Turn Anything into a Wiki

=head1 SYNOPSIS

    > cogwiki init
    > cp .wiki/config.yaml.example .wiki/config.yaml
    > edit .wiki/config.yaml
    > cogwiki make
    > cogwiki up

=head1 DESCRIPTION

CogWiki lets you turn any directory on your computer into a wiki. Every
file in the directory is a wiki page. All CogWiki files are put into a
C<.wiki/> subdirectory. CogWiki uses git for wiki history. If your
directory is already a git repo, CogWiki can use its GIT_DIR, or it can
set up its own. CogWiki is a Perl PSGI program, so you can run it in any
web environment. The 'up' command will start a local web server that you
can use immediately (even offline).

=head1 COMMANDS

The cogwiki command has a number of simple subcommands:

=head2 init

The C<init> command creates a .wiki subdirectory with all the necessary
components, thus making your directory into a wiki.

The most important file is .wiki/config.yaml. It is the configuration
file for the wiki. Whenever you change it, you need to run C<cogwiki
make> to apply the updates. See below.

=head2 make

The C<make> command performs all the actions necessary to bring your
wiki up to date. Whenever you change anything (new or updated file,
configuration changes, etc) just run C<cogwiki build> to apply the
changes to the wiki.

The wiki will run this for you, when you make changes through your
web browser. SW can also be configured to run C<make> when you do
git commits.

=head2 up [plackup-options]

This command will start a localhost web server for you. By default, you
can access the wiki on http://127.0.0.1:5000.

This command is a proxy for Perl Plack's plackup. That means you can use
all the same options as plackup. See L<plackup> for more information.

=head2 down

This command will attempt to stop the web server started by
C<cogwiki up>.

=head1 CONFIGURATION

After you run the C<cogwiki init> command, you will have a file
called C<.wiki/config.yaml>. See L<CogWiki::Manual::Configuration>
for full details.

=head1 

=head1 SEE

See L<CogWiki::Manual> for complete documentation.

=head1 AUTHOR

Ingy döt Net <ingy@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2010. Ingy döt Net.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
