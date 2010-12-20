package Cog::Config;
use Mouse;
use YAML::XS;
use IO::All;

# use XXX;

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
has site_navigation => (is => 'ro', default => sub{[]});

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

    $self->build_plugin_list();

    $self->build_class_share_map();

    $self->build_list('url_map', 'lol');
    $self->build_list('site_navigation', 'lol');

    $self->build_list('js_files');
    $self->build_list('css_files');
    $self->build_list('image_files');
    $self->build_list('template_files');

    return $self;
}

sub build_plugin_list {
    my $self = shift;
    my $list = $self->plugins;
    my @plugins = @$list;
    my $expanded = {};
    for my $plugin (@plugins) {
        $self->expand_list($list, $plugin, $expanded);
    }
    if (not grep {$_ eq 'Cog'} @$list) {
        require Cog;
        unshift @$list, 'Cog';
    }
        
    $self->{plugins} = $list;
}

sub expand_list {
    my ($self, $list, $plugin, $expanded) = @_;
    return if $expanded->{$plugin};
    $expanded->{$plugin} = 1;
    eval "use $plugin; 1" or die;
    my $adds = $plugin->plugins;
    push @$adds, $plugin
        unless grep {$_ eq $plugin} @$adds;
    for (my $i = 0; $i < @$list; $i++) {
        if ($list->[$i] eq $plugin) {
            splice(@$list, $i, 1, @$adds);
            last;
        }
    }
    my @plugins = @$list;
    for $plugin (@plugins) {
        $self->expand_list($list, $plugin, $expanded);
    }
}

sub build_list {
    my $self = shift;
    my $name = shift;
    my $list_list = shift || 0;
    my $finals = $self->$name;
    my $list = [];
    my $plugins = $self->plugins;
    my $method = $list_list ? 'add_to_list_list' : 'add_to_list';
    for my $plugin (@$plugins) {
        $self->$method($list, $plugin->$name);
    }
    $self->$method($list, $finals);
    $self->{$name} = $list;
}

sub add_to_list {
    my ($self, $list, $adds) = @_;
    my $point = @$list;
    for my $add (@$adds) {
        if ($add eq '()') {
            $point = @$list = ();
        }
        elsif ($add eq '^^') {
            $point = 0;
        }
        elsif ($add eq '$$') {
            $point = @$list;
        }
        elsif ($add eq '++') {
            $point++ if $point < @$list;
        }
        elsif ($add eq '--') {
            $point-- if $point > 0;
        }
        elsif ($add =~ s/^(\-\-|\+\+) *//) {
            my $indicator = $1;
            for ($point = 0; $point < @$list; $point++) {
                if ($add eq $list->[$point]) {
                    splice(@$list, $point, 1)
                        if $indicator eq '--';
                    $point++
                        if $indicator eq '++';
                    last;
                }
            }
        }
        else {
            splice(@$list, $point++, 0, $add); 
        }
    }
}

sub add_to_list_list {
    my ($self, $list, $adds) = @_;
    my $point = @$list;
    for my $add (@$adds) {
        if (not ref $add and $add eq '()') {
            $point = @$list = ();
        }
        else {
            splice(@$list, $point++, 0, $add); 
        }
    }
}

sub build_class_share_map {
    my $self = shift;
    my $plugins = $self->plugins;
    my $class_share_map = $self->class_share_map;
    for my $plugin (@$plugins) {
        (my $path = "$plugin.pm") =~ s!::!/!g;
        $path = $INC{$path} or die;
        # NOTE: $path is for dev testing.
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
        $class_share_map->{$plugin} = $dir;
    }
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
