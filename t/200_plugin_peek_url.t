use strict;
use lib "t/lib";
use Test::More;
use Test::MockObject::Extends;
use Morris;
use Morris::Message;
use Morris::Plugin::PeekURL;
use Morris::Test qw(have_connection);

if (have_connection('http://twitter.com')) {
    plan(tests => 1);
} else {
    plan(skip_all => "No connection to twitter.com");
}

my $cv = AnyEvent->condvar;
my $conn = Test::MockObject::Extends->new('Morris::Connection');
$conn->mock( irc_notice => sub {
    my ($self, $args) = @_;

    like( $args->{message}, qr/Morris用のテストです。/);
    $cv->send;
} );

my $plugin = Morris::Plugin::PeekURL->new();
$plugin->register( $conn );
$plugin->handle_message( 
    Morris::Message->new(
        channel => '#test',
        message => 'http://twitter.com/lestrrat/status/5614433545',
        from    => 'lestrrat!lestrrat@some.host',
    )
);

my $w; $w = AnyEvent->timer(after => 30, cb => sub { undef $w; $cv->send });
$cv->recv;
