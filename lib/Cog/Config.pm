package Cog::Config;
use Mouse;
use File::ShareDir;

use IO::All;

use XXX;

### These options are set by user in config file:

# Common webapp options
has site_name => (is => 'ro');
has home_page_id => (is => 'ro');
has html_title => (is => 'ro');

# Server options
has server_port => (is => 'ro', default => '');
has plack_debug => (is => 'ro', default => 0);
has proxymap => (is => 'ro', default => '');

### These fields are part of the Cog framework:

# Bootstrapping config values (root directories)
has app_class => (
    is => 'ro',
    required => 1,
);
has app_root => (
    is => 'ro',
    lazy => 1,
    default => ($ENV{COG_APP_ROOT_DIR} || 'cog'),
);
has store_root => (
    is => 'ro',
    lazy => 1,
    default => '.',
);
has content_root => (
    is => 'ro',
    lazy => 1,
    default => '..',
);

# Cog singleton object references
has webapp => (
    is => 'ro',
    lazy => 1,
    builder => sub { $_[0]->object_builder('webapp', 'Cog::WebApp') },
);
has runner => (
    is => 'ro',
    lazy => 1,
    builder => sub {
        $_[0]->classes->{runner} = $_[0]->webapp->runner_class;
        $_[0]->object_builder('runner', 'Cog::WebApp::Runner');
    },
);
has store => (
    is => 'ro',
    lazy => 1,
    builder => sub { $_[0]->object_builder('store', 'Cog::Store') },
);
has maker => (
    is => 'ro',
    lazy => 1,
    builder => sub { $_[0]->object_builder('maker', 'Cog::Maker') },
);

sub object_builder {
    my ($self, $type, $base) = @_;
    my $class = $self->classes->{$type};
    unless (UNIVERSAL::isa($class, $base)) {
        eval "require $class; 1" or die $@;
    }
    return $class->new();
}

# App Command Values
has command_script => (is => 'rw');
has command_args => (is => 'rw', default => sub{[]});

# App & WebApp definitions
has url_map => (is => 'ro', default => sub{[]});
has js_files => (is => 'ro', default => sub{[]});
has css_files => (is => 'ro', default => sub{[]});
has image_files => (is => 'ro', default => sub{[]});
has template_files => (is => 'ro', default => sub{[]});
has site_navigation => (is => 'ro', default => sub{[]});
has files_map => (is => 'ro', builder => '_build_files_map', lazy => 1);
has classes => (is => 'rw');

# App readiness
has is_init => (is => 'ro', default => 0);
has is_config => (is => 'ro', default => 0);
has is_ready => (is => 'ro', default => 0);

# Private accessors
has _plugins => (is => 'ro', default => sub{[]});
has _class_share_map => (is => 'ro', default => sub{{}});


# Build the config object scanning through all the classes and merging
# their capabilites together appropriately.
#
# This is the hard part...
sub BUILD {
    my $self = shift;
    my $root = $self->app_root;
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

    $self->find_classes();

    return $self;
}

sub build_plugin_list {
    my $self = shift;
    my $list = [];
    my $expanded = {};
    $self->expand_list($list, $self->app_class, $expanded);

    $self->{_plugins} = $list;
}

sub expand_list {
    my ($self, $list, $plugin, $expanded) = @_;
    return if $expanded->{$plugin};
    $expanded->{$plugin} = 1;
    unshift @$list, $plugin;
    my $adds = [];
    my $parent;
    {
        no strict 'refs';
        $parent = ${"${plugin}::ISA"}[0];
    }
    if ($plugin->isa('Cog::App')) {
        if ($plugin->webapp_class) {
            push @$adds, $plugin->webapp_class;
        }
        push @$adds, $parent
            unless $parent =~ /^(Cog::Base|Cog::Plugin)$/;
    }
    elsif ($plugin->isa('Cog::WebApp')) {
        push @$adds, $parent
            unless $parent =~ /^(Cog::Base|Cog::Plugin)$/;
    }
    push @$adds, @{$plugin->plugins};

    for my $add (@$adds) {
        $self->expand_list($list, $add, $expanded);
    }
}

sub build_list {
    my $self = shift;
    my $name = shift;
    my $list_list = shift || 0;
    my $finals = $self->$name;
    my $list = [];
    my $plugins = $self->_plugins;
    my $method = $list_list ? 'add_to_list_list' : 'add_to_list';
    for my $plugin (@$plugins) {
        my $function = "${plugin}::$name";
        next unless defined(&$function);
        no strict 'refs';
        $self->$method($list, &$function());
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
    my $plugins = $self->_plugins;
    my $class_share_map = $self->_class_share_map;
    for my $plugin (@$plugins) {
        my $dir = $self->find_share_dir($plugin)
            or die "Can't find share dir for $plugin";
        $class_share_map->{$plugin} = $dir
            if $dir;
    }
}

sub find_share_dir {
    my $self = shift;
    my $plugin = shift;

    my $module = "$plugin.pm";
    $module =~ s!::!/!g;
    while (1) {
        my $dir = $INC{$module} or last;
        $dir =~ s!(blib/)?lib/\Q$module\E$!! or last;
        $dir .= "share";
        return $dir if -e $dir;
        last;
    }

    (my $dist = $plugin) =~ s/::/-/g;
    my $dir = eval { File::ShareDir::dist_dir($dist) };
    return $dir if $dir;

    my $func = "${plugin}::SHARE_DIST";
    no strict 'refs';
    return '' unless defined &$func;
    $dist = &$func();
    $dir = eval { File::ShareDir::dist_dir($dist) };
    return $dir if $dir;

    $dist =~ s!-!/!g;
    $dist .= '.pm';
    $dir = $INC{$dist} or return '';
    $dir =~ s!(blib/)?lib/\Q$dist\E$!! or return '';
    $dir .= "share";
    return $dir if -e $dir;

    return '';
}

sub find_classes {
    my $self = shift;
    my $classes = {};
    for my $plugin (@{$self->_plugins}) {
        next unless $plugin->can('cog_classes');
        $classes = +{ %$classes, %{$plugin->cog_classes} };
    }
    $self->classes($classes);
}

sub _build_files_map {
    my $self = shift;

    my $hash = {};

    my $plugins = $self->_plugins;

    for my $plugin (@$plugins) {
        my $dir = $self->_class_share_map->{$plugin} or next;
        for (io->dir($dir)->All_Files) {
            my $full = $_->pathname;
            my $short = $full;
            $short =~ s!^\Q$dir\E/?!! or die;
            $hash->{$short} = $full;
        }
    }

    return $hash;
}

# Put the App in the context of its defined root directory.
sub chdir_root {
    my $self = shift;
    chdir $self->app_root;
}

1;
