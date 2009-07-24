use strict;
use Test::More (tests => 100);
use POE;

BEGIN
{
    use_ok("Morris");
}

my $nickname = $ENV{IRC_NICKNAME} || 'morris-test';
my $server   = $ENV{IRC_SERVER} || 'chat.freenode.com';
{
    my $conn = Morris::Connection->new(
        nickname => $nickname,
        server   => $server,
        plugins  => {
            '+Test::Morris::Plugin01' => {}
        }
    );

    ok($conn);
    isa_ok($conn, 'Morris::Connection');

    POE::Session->create(
        args => [ $conn ],
        inline_states => {
            _start => sub {
                my ($kernel, $conn) = @_[KERNEL, ARG0];
                $conn->start();
            }
        }
    );
    POE::Kernel->run();
}

package Test::Morris::Plugin01;
use Moose;

with 'Morris::Plugin';

no Moose;

sub register {
    my ($self, $conn) = @_;

    $conn->register_hook(
        'server.connected' => sub {
            Test::More::ok(1, 'server.connected called');
        }
    );
}