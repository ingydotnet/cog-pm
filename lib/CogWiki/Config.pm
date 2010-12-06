package CogWiki::Config;
use Mouse;
use YAML::XS;

use XXX;

has is_init => (is => 'ro', default => 0);
has is_config => (is => 'ro', default => 1);
has not_config => (is => 'ro', default => 0);
has root_dir => (is => 'ro', default => '.');

around BUILDARGS => sub {
    my ($orig, $class) = splice @_, 0, 2;
    my $config_file = shift || $class->get_config_file
        or return $class->$orig({is_init => 0});
    my $hash = YAML::XS::LoadFile($config_file);
    $hash->{is_init} = 1;
    $class->$orig($hash);
};

sub BUILD {
    my $self = shift;
    if ($self->not_config) {
        $self->is_config(0);
        return $self;
    }
    chdir $self->root_dir or die;
    return $self;
}

sub get_config_file {
    my $class = shift;
    my $file = '.wiki/config.yaml';
    return '' unless -e $file;
    $file =~ s!(.*/)!!;
    chdir $1 or die;
    return -f $file;
}

1;
