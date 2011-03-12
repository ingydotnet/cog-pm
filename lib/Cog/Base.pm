package Cog::Base;
use Mouse;

# System singleton object pointers.
my $config;
my $content;
my $maker;
my $runner;
my $store;
my $webapp;
my $view;

# The config reference must be initialized at startup.
sub initialize { $config ||= $_[1] }

# The accessors to common singleton objects are kept in single file
# scoped lexicals, so that every Cog::Base subclass can access them
# without needing to store them in their objects. This keeps things
# clean and fast, and avoids needless circular refs.
sub config { $config }
sub content { $content || ($content = $config->content) }
sub maker { $maker || ($maker = $config->maker) }
sub runner { $runner || ($runner = $config->runner) }
sub store { $store || ($store = $config->store) }
sub webapp { $webapp || ($webapp = $config->webapp) }
sub view { $view || ($view = $config->view) }

# Cog plugins need to know their distribution name. This name is used to
# locate shared files using File::ShareDir and other methods.
#
# This method will figure out the correct dist name most of the time.
# Otherwise the class can hardcode it like this:
#
# package Foo::Bar;
# use constant DISTNAME => 'Foo-X';
sub DISTNAME {
    my $class = shift;
    my $module = $class;
    while (1) {
        no strict 'refs';
        last if ${"${module}::VERSION"};
        eval "require $module";
        last if ${"${module}::VERSION"};
        $module =~ s/(.*)::.*/$1/
            or die "Can't determine DISTNAME for $class";
    }
    my $dist = $module;
    $dist =~ s/::/-/g;
    return $dist;
}

1;
