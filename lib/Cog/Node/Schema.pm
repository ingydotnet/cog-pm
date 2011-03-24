package Cog::Node::Schema;
use Mouse;
extends 'Cog::Schema';

use constant type => 'CogNode';
use constant parent => '';
use constant fields => [
    'Id',
    'Rev',
    'Type',
    'Time',
    'User',
    ['Name*', ['Name', key => 'flatten $v']],
    'Tag*',
    'Url*',
    'From?',
    'Body?',
    'Format?',
];
use constant perl_class => 'Cog::Node';

1;
