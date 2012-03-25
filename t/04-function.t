#!perl -T

use strict;
use warnings;

use Test::More;
use Test::Exception;

BEGIN {
    use_ok 'WebService::XING::Function';
    use_ok 'WebService::XING::Function::Parameter';
}

my @required = qw(name method resource params_in);
my $f;

dies_ok { $f = WebService::XING::Function->new } 'missing required attributes';

for my $attr (@required) {
    dies_ok {
        $f = WebService::XING::Response->new(map { $_ => 1 } grep { $attr ne $_ } @required)
    } "missing attribute $attr";
}

lives_ok {
    $f = WebService::XING::Function->new(
        name => 'create_foo_bar',
        method => 'POST',
        resource => '/v1/foo/:id/bar',
        params_in => ['!mumble', '@bumble', '?rumble=1'],
    );
} 'create a WebService::XING::Function object';

is "$f", 'create_foo_bar', 'stringifies correctly';

is_deeply $f->params, [
    WebService::XING::Function::Parameter->new(
        name => 'id', is_required => 1, is_placeholder => 1, default => undef
    ),
    WebService::XING::Function::Parameter->new(
        name => 'mumble', is_required => 1, default => undef
    ),
    WebService::XING::Function::Parameter->new(
        name => 'bumble', is_list => 1, default => undef
    ),
    WebService::XING::Function::Parameter->new(
        name => 'rumble', is_boolean => 1, default => 1
    ),
], 'function params list is built correctly';

isa_ok $f->code, 'CODE', 'function code';

done_testing;
