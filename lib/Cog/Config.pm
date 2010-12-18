package Cog::Config;
use Mouse;
use YAML::XS;
use IO::All;

use XXX;

my $root_dir = ($ENV{COG_ROOT_DIR} || '.cog');
has root_dir => (is => 'ro', default => $root_dir);

has site_name => (is => 'ro');
has home_page_id => (is => 'ro');
has server_port => (is => 'ro', default => '');

has content_root => (is => 'ro', default => '..');

has is_init => (is => 'ro', default => 0);
has is_config => (is => 'ro', default => 0);
has is_ready => (is => 'ro', default => 0);

has plugins => (is => 'ro', default => sub{[]});

has plack_debug => (is => 'ro', default => 0);

has url_map => (is => 'ro', default => sub{[]});

has js_files => (is => 'ro', default => sub{[]});
has css_files => (is => 'ro', default => sub{[]});
has image_files => (is => 'ro', default => sub{[]});
has template_files => (is => 'ro', default => sub{[]});

has class_share_map => (is => 'ro', default => sub{{}});

has files_map => (is => 'ro', builder => '_build_files_map', lazy => 1);

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

    my $plugins = $self->plugins;
    unshift @$plugins, 'Cog';
    my $url_map = $self->url_map;
    my $js_files = $self->js_files;
    my $css_files = $self->css_files;
    my $image_files = $self->image_files;
    my $template_files = $self->template_files;
    my $class_share_map = $self->class_share_map;

    for my $plugin (@$plugins) {
        my $module = $plugin;
        eval "use $plugin; 1" or die;
        my $object = $module->new;

        (my $path = "$plugin.pm") =~ s!::!/!g;
        $path = $INC{$path} or die;
        $path =~ s!^(\Q$ENV{HOME}\E.*)/lib/.*!$1/share!;
        my $dir = -e $path
            ? $path
            : do {
                (my $dist = $plugin) =~ s/::/-/g;
                eval { File::ShareDir::dist_dir($dist) } || do {
                    $_ = $@ or die;
                    /.* at (.*\/\.\.)/s or die;
                    "$1/share/";
                };
            };
        $class_share_map->{$module} = $dir;
        push @$js_files, @{$object->js_files};
        push @$css_files, @{$object->css_files};
        push @$image_files, @{$object->image_files};
        push @$template_files, @{$object->template_files};
        push @$url_map, @{$object->url_map};
    }
    return $self;
}

sub _build_files_map {
    require File::ShareDir;
    my $self = shift;

    my $hash = {};

    my $plugins = $self->plugins;

    for my $plugin (@$plugins) {
        my $dir = $self->class_share_map->{$plugin};
        for (io->dir($dir)->All_Files) {
            my $full = $_->pathname;
            my $short = $full;
            $short =~ s!^\Q$dir\E/?!! or die;
            $hash->{$short} = $full;
        }
    }

    return $hash;
}

sub chdir_root {
    my $self = shift;
    chdir $self->root_dir;
    $self->{root_dir} = '.';
}


1;
