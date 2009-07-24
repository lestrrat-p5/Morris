# $Id: Generator.pm 19289 2008-09-14 09:38:32Z daisuke $

package Morris::Plugin::Reply::Generator;
use Moose::Role;

with 'Morris::Plugin';

requires 'match';

no Moose::Role;

sub register {
    my ($self, $conn) = @_;
    $conn->register_hook( 'channel.public', sub { $self->generate(@_) } );
}

sub generate
{
    my ($self, $args) = @_;

    my $message = $args->{message};
    if (my $reply = $self->match({ message => $message })) {
        $self->irc_privmsg( {
            channel => $message->channel,
            message => $reply,
        } );
    }
}

1;