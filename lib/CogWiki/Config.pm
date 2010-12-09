package CogWiki::Config;
use Mouse;
use YAML::XS;
use Cwd;

# use XXX;

has is_init => (is => 'ro', default => 0);
has is_config => (is => 'ro', default => 1);
has not_config => (is => 'ro', default => 0);
has is_ready => (is => 'ro', default => 0);
has root_dir => (is => 'ro', default => '.');
has site_name => (is => 'ro');
has content_root => (is => 'ro');
has server_port => (is => 'ro', default => '');

around BUILDARGS => sub {
    my ($orig, $class) = splice @_, 0, 2;

    my $config_file = '.wiki/config.yaml';
    my $hash = {is_init => 0};
    if (-e $config_file) {
        $hash = YAML::XS::LoadFile($config_file);
        $hash->{is_init} = 1;
        $config_file =~ s!(.*)/!!;
        $hash->{root_dir} = $1;
    }
    $class->$orig($hash);
};

sub BUILD {
    my $self = shift;
    if ($self->not_config) {
        $self->{is_config} = 0;
        return $self;
    }
    if (-d $self->root_dir) {
        $self->{is_ready} = 1;
    }
    return $self;
}

sub chdir_root {
    my $self = shift;
    chdir $self->root_dir;
    $self->{root_dir} = '.';
}

1;
