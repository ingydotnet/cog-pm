use Test::More tests => 29;
use t::Tests;

my $PATH = 't/cog1';

rmpath $PATH;
mkpath $PATH;
cd $PATH;
run_pass "$PERL $CWD/bin/cog init -a Cog::App::Test";

is $STDOUT, <<"...", 'STDOUT is good';
Cog was successfully initialized in:

    $CWD/t/cog1/cog

The next step is to edit:

    $CWD/t/cog1/cog/config.yaml

Then run:

    $CWD/bin/cog update

...

files_exist qw(
    cog/config.yaml
    cog/static/css/page-list.css
    cog/static/css/layout.css
    cog/static/css/page-display.css
    cog/static/image/tile.gif
    cog/static/js/cog.js
    cog/static/js/separator.js
    cog/static/js/jquery.cookie.js
    cog/static/js/start.js
    cog/static/js/jquery-1.4.4.min.js
    cog/template/page-list.html
    cog/template/config.js
    cog/template/tag-list.html
    cog/template/js-mf.mk
    cog/template/page-display.html
    cog/template/css-mf.mk
    cog/template/url-map.js
    cog/template/layout.html
    cog/template/config.yaml
    cog/template/site-navigation.html
    cog/template/404.html
);

file_has_line
    'cog/config.yaml',
    'app_class: Cog::App::Test';

cd;
rmpath $PATH;
