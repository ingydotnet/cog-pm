package Cog::Node::Schema;
use Mouse;
extends 'Cog::Schema';

use constant type => 'CogNode';
use constant parent => '';
use constant fields => [
    'Id',
    'Rev',
    'Time',
    'User',
    'Name*',
    'Tag*',
    'Url*',
    'Body?',
    'Format?',
];
use constant perl_class => 'Cog::Node';

1;
