use inc::Module::Install;

name     'WebService-XING';
all_from 'lib/WebService/XING.pm';
author   'Bernhard Graf <graf (?) cpan.org>';
license  'perl';

perl_version '5.010000';

test_requires 'Test::More';
test_requires 'Test::Exception';

requires 'HTTP::Headers';
requires 'HTTP::Request';
requires 'JSON' => 2;
requires 'LWP::UserAgent';
requires 'Mo' => 0.30;
requires 'Net::OAuth';
requires 'URI';

resources(
    homepage   => 'https://github.com/augensalat/webservice-xing',
    repository => 'git://github.com/augensalat/webservice-xing.git',
);

auto_install;

WriteAll;
