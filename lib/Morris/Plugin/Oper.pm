package Morris::Plugin::Oper;
use Moose;
use namespace::clean -except => qw(meta);

# <Oper>
#   <Channel #foo>
#       Op regexp
#       Op regexp
#   </Channel>
# </Oper>

extends 'Morris::Plugin';

has channels => (
    is => 'ro',
    isa => 'HashRef[HashRef[ArrayRef]]',
    required => 1,
);

override new_from_config => sub {
    my ($class, $args) = @_;

    my $channels = delete $args->{channel};
    if ($channels) {
        if (ref $channels ne 'HASH') {
            confess "Oper -> Channel must be a hash";
        }

        while (my ($channel, $config) = each %$channels) {
            if (ref $config->{op} ne 'ARRAY') {
                $config->{op} = [ $config->{op} ];
            }
        }

        $args->{channels} = $channels;
    }
    $class->new(%$args);
};

after register => sub {
    my ($self, $conn) = @_;
    $conn->register_hook( 'channel.joined', sub {
        $self->handle_message(@_);
    });
};

sub handle_message {
    my ($self, $channel, $address) = @_;

    my $config  = $self->channels->{ $channel } ||
        $self->channels->{ '*' };
    if (! $config) {
        return;
    }

    my $id = ${ $address->str_ref };
    if ( grep { $id =~ /$_/ } @{ $config->{op} } ) {
        $self->connection->irc_mode({
            channel => $channel,
            mode    => '+o',
            who     => $address->nickname,
        });
    }
}

__PACKAGE__->meta->make_immutable();

1;