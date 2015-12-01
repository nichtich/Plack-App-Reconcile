use v5.14.1;
use Test::More;
use Plack::App::Reconcile;

eval { Plack::App::Reconcile->new() };
ok $@, 'missing options';

done_testing;
