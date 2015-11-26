use v5.14.1;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use JSON;

use_ok 'Plack::App::Reconcile';

my $app = Plack::App::Reconcile->new();
my $test = Plack::Test->create($app);

my $res = $test->request(GET '/');
is $res->code, 200, 'app does not always fail';

# ...

done_testing;
