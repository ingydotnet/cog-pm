package CogWiki::Config;
use Mouse;
use YAML::XS;

# use XXX;

my $root_dir = ($ENV{COGWIKI_ROOT} || '.wiki');
has root_dir => (is => 'ro', default => $root_dir);

has site_name => (is => 'ro');
has home_page_id => (is => 'ro');
has server_port => (is => 'ro', default => '');

has content_root => (is => 'ro', default => '..');

has is_init => (is => 'ro', default => 0);
has is_config => (is => 'ro', default => 0);
has is_ready => (is => 'ro', default => 0);

has plack_debug => (is => 'ro', default => 0);

around BUILDARGS => sub {
    my ($orig, $class) = splice @_, 0, 2;

    my $config_file = "$root_dir/config.yaml";
    my $hash = -e $config_file
        ? YAML::XS::LoadFile($config_file)
        : {};
    $class->$orig($hash);
};

sub BUILD {
    my $self = shift;
    my $root = $self->root_dir;
    $self->{is_init} = 1
        if -d "$root/static";
    $self->{is_config} = 1
        if -e "$root/config.yaml";
    $self->{is_ready} = 1
        if -d "$root/static";
    return $self;
}

sub chdir_root {
    my $self = shift;
    chdir $self->root_dir;
    $self->{root_dir} = '.';
}

1;
