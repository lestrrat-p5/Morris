# $Id: Engine.pm 24702 2008-11-23 14:12:32Z daisuke $

package Morris::Engine;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::AttributeHelpers;
use Morris::Connection;
use POE;
use namespace::clean -except => qw(meta);

has 'poe_main_session' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    default => 'morris-engine'
);

has 'resources' => (
    metaclass => 'Collection::Hash',
    is => 'rw',
    isa => 'HashRef',
    default => sub { +{} },
    provides => {
        get => 'resource',
        set => 'set_resource',
    }
);

has 'connections' => (
    metaclass => 'Collection::Array',
    is => 'rw',
    isa => 'ArrayRef[Morris::Connection]',
    default => sub { +[] },
    provides => {
        push => 'push_connection',
    },
);

has 'config' => (
    is => 'rw',
    does => 'MooseX::Getopt',
);

__PACKAGE__->meta->make_immutable;

sub BUILD {
    my $self        = shift;
    my $config      = $self->config;
    my $connlist    = delete $config->{connection} or die "no connection definition provided";
    my $connections = [];
    while ( my ($name, $conn) = each %$connlist) { 
        my $network = $config->{network}->{ $conn->{network} };
        $network->{server} ||= $conn->{network};

        my $connection = Morris::Connection->new(
            %$conn,
            %$network,
            config => $config,
            engine => $self,
        );
        $self->push_connection($connection);
    }

    return $self;
}

sub run {
    my $self = shift;

    POE::Session->create(
        options => {trace => 1, debug => 1},
        object_states => [
            $self => {
                map {
                    my $k = $_;
                    $k =~ s/^_?/poe_/;
                    ($_ => $k)
                } qw( _start _stop)
            }
        ]
    );
    POE::Kernel->run();
    exit 0;
}

sub poe_start {
    my ($self, $kernel) = @_[ OBJECT, KERNEL ];

    $kernel->alias_set($self->poe_main_session);
    foreach my $conn (@{ $self->connections }) {
        $conn->start();
    }

#    $kernel->delay( check_config_reload => 1 );
#    $kernel->yield('poe_call_hook', 'prepare');
#    $kernel->yield('poe_call_hook', 'connect');
}

sub poe_stop {
    my ($self, $kernel) = @_[ OBJECT, KERNEL ];
    $kernel->alias_remove($self->poe_main_session);
}

1;
