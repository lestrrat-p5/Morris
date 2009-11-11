package Morris::Plugin::DBI;
use Moose;
use AnyEvent::DBI;
use namespace::clean -except => qw(meta);

extends 'Morris::Plugin';

# This plugin does not respond to anything, but it just acts as a 
# shared resource for others

has instances => (
    traits => ['Hash'],
    is => 'ro',
    isa => 'HashRef',
    handles => {
        get_instance => 'get',
    }
);

around BUILDARGS => sub {
    my ($next, $self, @args) = @_;
    my $args = $next->($self, @args);

    # convert each instance into a real DBI handle
    my $instances = $args->{instances} ||= delete $args->{instance};
    foreach my $name ( keys %$instances ) {
        my $config = $instances->{$name};
        $instances->{$name} = AnyEvent::DBI->new(
            $config->{dsn},
            $config->{username},
            $config->{password},
            (%{ $config->{options} || {} }, exec_server => 1 ),
        );
    }
    return $args;
};

after register => sub {
    my ($self, $conn) = @_;
    # Add a get_dbh method by reblessing the connection instance to
    # a newly created anon class
    my $meta = $conn->meta;
    my $new_meta = Moose::Meta::Class->create_anon_class(
        superclasses => [ $meta->name ],
        cache        => 1,
        methods      => {
            get_dbh => sub {
                my $name = $_[1];
                $self->get_instance( $name );
            }
        }
    );
    $new_meta->rebless_instance( $conn );
};

__PACKAGE__->meta->make_immutable();

1;