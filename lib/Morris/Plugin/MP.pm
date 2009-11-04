package Morris::Plugin::MP;
use Moose;
use AnyEvent::MP qw(configure port rcv);
use AnyEvent::MP::Global qw(grp_reg);
use namespace::clean -except => qw(meta);

extends 'Morris::Plugin';

has group => (
    is => 'ro',
    isa => 'Str',
    default => 'morris',
    required => 1,
);

has profile => (
    is => 'ro',
    isa => 'Str',
    default => 'morris',
    required => 1,
);

has __guard => (
    is => 'rw',
    clearer => 'clear_guard',
);

after register => sub {
    my ($self, $conn) = @_;

    configure profile => $self->profile;

    my $server = port;
    rcv $server, notice => sub {
        my ($channel, $message) = @_;
        $conn->irc_notice( {
            channel => $channel,
            message => $message
        });
    };
    rcv $server, privmsg => sub {
        my ($channel, $message) = @_;
        $conn->irc_privmsg( {
            channel => $channel,
            message => $message
        });
    };
    $self->__guard( grp_reg $self->group, $server );
};

sub DEMOLISH {
    my $self = shift;
    $self->clear_guard();
}

__PACKAGE__->meta->make_immutable();

1;
