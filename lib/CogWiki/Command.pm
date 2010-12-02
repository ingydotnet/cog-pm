package CogWiki::Command;
use Mouse;
use Try::Tiny;
use Class::Throwable qw(Error);
use CogWiki::App;
use XXX;

has 'app' => (is => 'ro', builder => sub {CogWiki::App->new});
has 'action' => (is => 'ro');
has 'argv' => (is => 'ro');

around BUILDARGS => sub {
    my ($orig, $class) = splice @_, 0, 2;
    $class->$orig($class->_parse_args(@_));
};

sub run {
    my $self = shift;
    my $method = "handle_" . $self->action;
    throw Error "'${\$self->action}' is an invalid action\n"
        unless $self->can($method);
    $self->$method();
    return 0;
}

sub handle_help {
    my $self = shift;
    print $self->usage;
}

sub handle_init {
    my $self = shift;
    try {
        $self->app->handle_init;
    }
    catch {
        chomp;
        throw Error "init failed.\n$_\n";
    };
}

sub handle_make {
    my $self = shift;
    try {
        $self->app->make;
    }
    catch {
        chomp;
        throw Error "make failed.\n$_\n";
    };
}

sub handle_up {
    require Plack::Runner;
    require CogWiki::PSGI;
    my $self = shift;
    try {
        my $runner = Plack::Runner->new();
        $runner->parse_options(@{$self->argv});
        my $app = CogWiki::PSGI->new->app;
        $runner->run($app);
    }
    catch {
        chomp;
        XXX $_;
        throw Error "up failed.\n$_\n";
    };
}

sub usage {
    my $self = shift;
    return <<'...';
Usage: cogwiki command

Commands:
    init - Make current directory into a CogWiki
    make - Bring the wiki up to date
    up   - Start up a local wiki server
    down - Stop the server

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

cogwiki - Turn Anything into a Wiki

=head1 SYNOPSIS

    > cogwiki init
    > edit .wiki/config.yaml
    > cogwiki make
    > cogwiki up

=head1 DESCRIPTION

CogWiki (SW) lets you turn any directory on your computer into a
wiki. Every file in the directory is a wiki page. All SW files are put
into a C<.wiki/> subdirectory. SW uses git for wiki history.
If your directory is already a git repo, SW can use its GIT_DIR, or it
can set up its own. SW is a Perl Plack program, so you can run it in any
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
called C<.wiki/config.yaml>. See
L<CogWiki::Manual::Configuration> for full details.

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
