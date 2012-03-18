#!perl -T

use strict;
use warnings;

use Test::More;
use Test::Exception;

BEGIN {
    use_ok 'WebService::XING';
}

my $xing;
my @ARGS = (key => 'TEST-KEY', secret => 'S3CR3T');

dies_ok { $xing = WebService::XING->new } 'missing required attributes';

$xing = WebService::XING->new(@ARGS);

isa_ok $xing, 'WebService::XING';
is $xing->base_url, 'https://api.xing.com', 'default base_url';
is $xing->request_token_resource, '/v1/request_token',
   'default request_token_resource';
is $xing->authorize_resource, '/v1/authorize',
   'default authorize_resource';
is $xing->access_token_resource, '/v1/access_token',
   'default access_token_resource';
is $xing->user_agent, "WebService::XING/$WebService::XING::VERSION (Perl)",
   'user agent id';
is $xing->key, 'TEST-KEY', 'consumer key';
is $xing->secret, 'S3CR3T', 'consumer secret';

ok !defined $xing->access_token, 'has no access token';
ok !defined $xing->access_secret, 'has no access secret';
ok !defined $xing->user_id, 'has no user_id';

is_deeply [$xing->access_credentials], [undef, undef, undef], 'no access credentials';

$xing->access_credentials('A-Side', 'B-side', 45);

is $xing->access_token, 'A-Side', 'has an access token';
is $xing->access_secret, 'B-side', 'has an access secret';
is $xing->user_id, 45, 'has a user_id';

is_deeply [$xing->access_credentials], ['A-Side', 'B-side', 45], 'has access credentials';

is(WebService::XING->new(@ARGS, warn => sub { shift() x 2 })->warn->('Bunga'),
   'BungaBunga', 'custom warn method');

is_deeply [sort @{$xing->functions}], [sort keys %{$xing->_functab}], 'function list';

my $f = $xing->function('get_network_feed');

isa_ok $f, 'WebService::XING::Function', 'function("get_network_feed")';

my $fp = $f->params;

isa_ok $fp, 'ARRAY', 'function parameter list';

for (@$fp) {
    isa_ok $_, 'WebService::XING::Function::Parameter', "function parameter $_";
}

is_deeply $fp, [qw(user_id aggregate since until user_fields)],
    'parameter list elements stringify';

is $fp->[0]->name, 'user_id', 'name of param 0';
ok $fp->[0]->is_required, 'param 0 is required';
ok !$fp->[0]->is_boolean, 'param 0 is not a boolean';
ok !$fp->[0]->is_list, 'param 0 is not a list';
ok !defined $fp->[0]->default, 'param 0 has no default';

is $fp->[1]->name, 'aggregate', 'name of param 1';
ok !$fp->[1]->is_required, 'param 1 is not required';
ok $fp->[1]->is_boolean, 'param 1 is a boolean';
ok !$fp->[1]->is_list, 'param 1 is not a list';
is $fp->[1]->default, 1, 'param 1 default == 1';

is $fp->[2]->name, 'since', 'name of param 2';
ok !$fp->[2]->is_required, 'param 2 is not required';
ok !$fp->[2]->is_boolean, 'param 2 is not a boolean';
ok !$fp->[2]->is_list, 'param 2 is not a list';
ok !defined $fp->[2]->default, 'param 2 has no default';

is $fp->[3]->name, 'until', 'name of param 3';
ok !$fp->[3]->is_required, 'param 3 is not required';
ok !$fp->[3]->is_boolean, 'param 3 is not a boolean';
ok !$fp->[3]->is_list, 'param 3 is not a list';
ok !defined $fp->[3]->default, 'param 3 has no default';

is $fp->[4]->name, 'user_fields', 'name of param 4';
ok !$fp->[4]->is_required, 'param 4 is not required';
ok !$fp->[4]->is_boolean, 'param 4 is not a boolean';
ok $fp->[4]->is_list, 'param 4 is a list';
ok !defined $fp->[4]->default, 'param 4 has no default';

done_testing;
