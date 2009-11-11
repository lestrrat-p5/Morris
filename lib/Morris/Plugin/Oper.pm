package Morris::Plugin::Oper;
use Moose;
use namespace::clean -except => qw(meta);

# TODO: for jshirley
#
#  <Connection whatever>
#    <Plugin DBI>
#      <Instance main>
#        dsn dbi:mysql:dbname=whatever
#      </Instance>
#    </Plugin>
#    <Plugin Oper::DBI>
#      dbname main
#    </Plugin>
#  </Connection>
#
# =head1 DESCRIPTION
# 
# See Morris::Plugin::Oper::DBI for ways to keep this data in a database

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

__END__

=head1 NAME

Morris::Plugin::Oper - Give Oper Rights Automatically

=head1 SYNOPSIS

  # in your config file
  <Connection whatever>
    <Plugin Oper>
      <Channel #foo>
        Op regexp
      </Channel>
    </Plugin>
  </Connection>

=cut
