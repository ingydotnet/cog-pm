package CogWiki::PSGI;
use Mouse;
use Class::Throwable qw(Error);

use Plack::Builder;
use CogWiki::App;

sub app {
    my $self = shift;

    my $webapp = CogWiki::App->new();
    throw Error "CogWiki is not set up"
        unless $webapp->config->is_wiki;

    return builder {
        mount "/static/" =>
            Plack::App::File(root => $webapp->config->static_dir);
        mount "/" => $webapp->dispatch;
    };
}

1;
