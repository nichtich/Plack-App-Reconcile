use v5.14.1;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use JSON;

use_ok 'Plack::App::Reconcile';

my $options = {
    name            => 'test sörvice',
    identifierSpace => 'http://example.org/id/',
    schemaSpace     => 'http://example.org/schema/',
};
my $app = Plack::App::Reconcile->new(%$options);
my $test = Plack::Test->create($app);

my $res = $test->request(GET '/');
is $res->code, 200, 'status code';
is $res->header('Content-Type'), 'application/json', 'content type';
is_deeply decode_json($res->content), $options, 'service metadata';    

$res = $test->request(GET '/?callback=abc');
like $res->content, qr{^/\*\*/abc\(.+\)}sm, 'JSONP';

$res = $test->request(GET '/?query=abc');
is_deeply decode_json($res->content), { result => [] }, 'empty query result';

done_testing;
