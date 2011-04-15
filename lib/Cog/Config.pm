#TODO:
# - Support uri_base
# - Support uri_port
# - Support uri_path
# - Support daemon, logfile and pid
# - plugins can update config to map urls to code
# - Make all config options 'foo' respect $COG_FOO
package Cog::Config;
use Mouse;
use File::ShareDir;
use Cwd qw(abs_path);

use IO::All;

# use XXX;

### These options are set by user in config file:

# Common webapp options
has site_name => (is => 'ro');
has home_page_id => (is => 'ro');
has html_title => (is => 'ro');

# Server options
has server_port => (is => 'ro', default => '');
has proxymap => (is => 'ro');
has cache_urls => (is => 'ro');

### These fields are part of the Cog framework:

# Bootstrapping config values (root directories)
has app_class => (
    is => 'ro',
    required => 1,
);
has app_root => (
    is => 'ro',
    lazy => 1,
    default => ($ENV{COG_APP_ROOT} || 'cog'),
);
has store_root => (
    is => 'ro',
    lazy => 1,
    builder => sub { abs_path('.') },
);
has content_root => (
    is => 'ro',
    lazy => 1,
    builder => sub { abs_path('.') },
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
has maker => (
    is => 'ro',
    lazy => 1,
    builder => sub { $_[0]->object_builder('maker', 'Cog::Maker') },
);
has store => (
    is => 'ro',
    lazy => 1,
    builder => sub { $_[0]->object_builder('store', 'Cog::Store') },
);
has content => (
    is => 'ro',
    lazy => 1,
    builder => sub { $_[0]->object_builder('content', 'Cog::Content') },
);
has view => (
    is => 'ro',
    lazy => 1,
    builder => sub { $_[0]->object_builder('view', 'Cog::View') },
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
has command_script => (is => 'ro');
has command_args => (is => 'ro', default => sub{[]});

# App & WebApp definitions
has url_map => (is => 'ro', default => sub{[]});
has post_map => (is => 'ro', default => sub{[]});
has js_files => (is => 'ro', default => sub{[]});
has css_files => (is => 'ro', default => sub{[]});
has image_files => (is => 'ro', default => sub{[]});
has template_files => (is => 'ro', default => sub{[]});
has site_navigation => (is => 'ro', default => sub{[]});
has files_map => (is => 'ro', builder => '_build_files_map', lazy => 1);
has classes => (is => 'rw');
has all_js_file => (is => 'rw');
has all_css_file => (is => 'rw');

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
    $self->build_list('post_map', 'lol');
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
    eval "use $plugin";
    die "use $plugin; error: $@"
        if $@ and $@ !~ /Can't locate/;
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

    my $dist = $plugin->DISTNAME;
    my $modpath = "$dist.pm";
    $modpath =~ s!-!/!g;

    while (1) {
        my $dir = $INC{$modpath} or last;
        $dir =~ s!(blib/)?lib/\Q$modpath\E$!! or last;
        $dir .= "share";
        return $dir if -e $dir;
        last;
    }

    my $dir = eval { File::ShareDir::dist_dir($dist) };
    return $dir if $dir;

    return;
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
            next if "$_" =~ /\.sw[p]$/;
            my $full = $_->pathname;
            my $short = $full;
            $short =~ s!^\Q$dir\E/?!! or die;
            $hash->{$short} = $full;
        }
    }

    return $hash;
}

1;
