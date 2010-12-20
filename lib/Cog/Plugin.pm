package Cog::Plugin;
use Mouse;

use constant plugin_type => '';

sub plugins { [] }

sub url_map { [] }
sub navigation { [] }

sub js_files { [] }
sub css_files { [] }
sub image_files { [] }
sub template_files { [] }

sub cog_classes { {} }

1;
