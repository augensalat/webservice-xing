#!perl -T

use Test::More;
use Test::Exception;

use HTTP::Headers;

BEGIN {
    use_ok 'WebService::XING::Error';
}

my $res;
my $headers = HTTP::Headers->new;
my @required = qw(code message headers content);

dies_ok { $res = WebService::XING::Error->new } 'missing required attributes';

for my $attr (@required) {
    dies_ok {
        $res = WebService::XING::Error->new(map { $_ => 1 } grep { $attr ne $_ } @required)
    } "missing attribute $attr";
}

lives_ok {
    $res = WebService::XING::Error->new(
        code => 403,
        message => 'Forbidden',
        headers => $headers,
        content => {
            error_name => 'INVALID_OAUTH_TOKEN',
            message => 'Invalid OAuth token',
        },
    );
} 'create a WebService::XING::Error 4xx response';

is $res->as_string, '403 Forbidden', 'as_string() works correctly';
is $res, '403 Forbidden', 'stringifies with as_string()';
ok $res == 403, 'numifies to code attribute';
ok !$res->is_success, 'is_success returns false';
ok !$res, 'use is_success() in boolean context';
is $res->error_name, 'INVALID_OAUTH_TOKEN', 'check error_name';
is $res->content_message, 'Invalid OAuth token', 'check content_message';

done_testing;
