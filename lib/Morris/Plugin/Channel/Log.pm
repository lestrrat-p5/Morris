# $Id: Log.pm 24007 2008-11-17 17:01:20Z daisuke $

package Morris::Plugin::Channel::Log;
use Moose::Role;

with 'Morris::Plugin';

has 'channel' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

requires 'log_message';

no Moose::Role;

sub register {
    my ($self, $conn) = @_;
    $conn->register_hook( 'channel.public', sub { $self->handle_message(@_) } );
}

sub should_handle_channel {
    my ($self, $message) = @_;
    my $channel = $self->channel;
    return 1 if $channel eq '*all*';
    return $channel eq $message->channel;
}

sub handle_message {
    my ($self, $args) = @_;

    my $message = $args->{message};

    # make sure this is from the correct channel
    if ( $self->should_handle_channel($message) ) {
        $self->log_message($args);
    }
}

1;
