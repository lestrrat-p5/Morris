package Morris::Plugin::Log;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Morris::Plugin';

has channel => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

after register => sub {
    my ($self, $conn) = @_;
    $conn->register_hook( 'chat.privmsg', sub { $self->handle_message(@_) } );
};

sub should_handle_channel {
    my ($self, $message) = @_;
    my $channel = $self->channel;
    return 1 if $channel eq '*all*';
    return $channel eq $message->channel;
}

sub handle_message {
    my ($self, $message) = @_;

    # make sure this is from the correct channel
    if ( $self->should_handle_channel($message) ) {
        $self->log_message($message);
    }
}

sub log_message {}

__PACKAGE__->meta->make_immutable();

1;