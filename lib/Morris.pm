package Morris;
use Moose;
use AnyEvent;
use Morris::Connection;
use namespace::clean -except => qw(meta);

our $VERSION = '0.01000';

has condvar => (
    is => 'ro',
    lazy_build => 1,
);

has connections => (
    traits => ['Array'],
    is => 'ro',
    isa => 'ArrayRef[Morris::Connection]',
    lazy_build => 1,
    handles => {
        push_connection => 'push',
        all_connections => 'elements',
    }
);

sub _build_condvar { AnyEvent->condvar }
sub _build_connections { [] }

sub new_from_config {
    my ($class, $config) = @_;

    my $self = $class->new();

    while ( my ($name, $conn) = each %{$config->{connection}}) {
        my $network = $config->{network}->{ $conn->{network} };
        $network->{server} ||= $conn->{network};

        my $connection = Morris::Connection->new_from_config( {
            %$conn,
            %$network,
            name   => $name,
        });
        $self->push_connection( $connection );
    }

    return $self;
}

sub run {
    my $self = shift;

    my $cv = $self->condvar;
    $cv->begin();
    foreach my $conn ($self->all_connections) {
        $conn->run();
    }
    $cv->recv;
}

__PACKAGE__->meta->make_immutable();

1;
