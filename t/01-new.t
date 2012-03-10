#!perl -T

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
is(WebService::XING->new(@ARGS, warn => sub { shift() x 2 })->warn->('Bunga'),
   'BungaBunga', 'custom warn method');


use Data::Dump;
# ddx $xing->request(POST => $xing->request_token_resource); #, callback => 'http://localhost/auth');

done_testing;
