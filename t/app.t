use v5.14.1;
use Plack::Test;
use Plack::Util;
use HTTP::Request::Common;
use Test::More;

my $app = Plack::Util::load_psgi("app.psgi");

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(GET "/");
    is $res->code, "200", "/ ok";
};

done_testing;
