# $Id: Join.pm 24700 2008-11-23 13:48:04Z daisuke $

package Morris::Plugin::Channel::Join;
use Moose;
use namespace::clean -except => qw(meta);

with 'Morris::Plugin';

has 'channels' => (
    is         => 'rw',
    isa        => 'ArrayRef[ArrayRef]',
    auto_deref => 1,
    default    => sub { +[] },
);

has 'auto_rejoin' => (
    is => 'rw',
    isa => 'Bool',
    default => 0
);

around new => sub {
    my $next  = shift;
    my $class = shift;
    my %args  = @_;

    if (! $args{channels} && $args{channel}) {
        my $channel = delete $args{channel};
        $args{channels} = ref $channel eq 'ARRAY' ? $channel : [ $channel ];
    }
    foreach (@{ $args{channels} }) {
        $_ = [ split(/\s*,\s*/, $_) ];
    }

    $next->($class, %args);
};

sub register {
    my ($self, $conn) = @_;

    my $join_sub = sub { $self->join_channels(@_) };
    $conn->register_hook( 'server.connected', $join_sub );
    if ($self->auto_rejoin) {
        $conn->register_hook( 'channel.disconnected' => $join_sub );
    }
}

sub join_channels {
    my $self = shift;
    $self->connection->irc_join( { channels => [ $self->channels ] } );
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;

__END__

=head1 NAME

Morris::Plugin::Channel::Join - Automatically Join A Channel On Connect

=head1 SYNOPSIS

  <Connection chat.example.com>
    ...

    <Plugin Channel::Join>
      Channel \#channel1,password
      Channel \#channel2
      Channel \#channel3
    </Plugin>
  </Connection>

=cut