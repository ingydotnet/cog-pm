package Cog::WebApp;
use Mouse;
extends 'Cog::Plugin';

use constant index_file => '';
use constant plugins => [];
use constant site_navigation => [];
use constant url_map => [];
use constant js_files => [qw(
    jquery-1.4.4.min.js
    jquery.cookie.js
    jemplate.js
    separator.js
    cog.js
    config.js
    url-map.js
    start.js
)];
use constant css_files => [qw(
    layout.css
    page-list.css
    page-display.css
)];
use constant image_files => [];
use constant template_files => [];
use constant runner_class => 'Cog::WebApp::Runner';

1;
