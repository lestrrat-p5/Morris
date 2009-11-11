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

__END__

=head1 NAME

Morris::Plugin::DBI - Register Database Instances To Be Used In Plugins

=head1 SYNOPSIS

    <Connection whatever>
      <Plugin DBI>
        <Instance db01>
          dsn dbi:SQLite:dbname=foo.db
        </Instance>
        <Instance db02>
          dsn dbi:mysql:dbname=bar
          username foo
        </Instance>
      </Plugin>

      <Plugin Some::Other::Plugin>
        dbname db01
      </Plugin>
      <Plugin Yet::Another::Plugin>
        dbname db02
      </Plugin>
    </Connection>

=head1 DESCRIPTION

This plugin creates a database store for plugins to use.

The associated Morris::Connection object will have a new method name 
C<get_dbh($name)> that will allow you to get a handle to AnyEvent::DBI 
object of that name.

Plugins may optionally consume the L<Morris::Plugin::WithDB> role to
implant a utility method C<get_dbh()> (on the plugin, not the connection), 
which will fetch the database specified in the C<dbname> configuration
parameter.

=head1 SEE ALSO

L<Morris::Plugin::WithDB>

=cut
