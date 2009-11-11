package Morris;
use Moose;
use AnyEvent;
use Morris::Connection;
use namespace::clean -except => qw(meta);

use constant DEBUG => $ENV{PERL_MORRIS_DEBUG};

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
sub _noop_cb {};

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
}

__PACKAGE__->meta->make_immutable();

1;

__END__

=head1 NAME

Morris - An IRC Bot Based On Moose/AnyEvent

=head1 SYNOPSIS

    # If you just want to start using Morris, please checkout misc/sample.conf
    # in the distro for a sample config file, which is the best way to figure 
    # out how to configure Morris.

    use Morris;

    my $morris = Morris->new(
        connections => [
            Morris::Connection->new( ... )
        ]
    );
    $morris->run();

    # or when you instantiate from a config file
    my $config = read_config_file( $config_file );
    my $morris = Morris->new_from_config( $config );
    $morris->run;

=head1 CONFIG FILE

The configuration file shipped with Morris is written in Config::General syntax,
but since our underlying config read is Config::Any, we support any format
supported by Config::Any family. Our docs will be written in Config::General
format, but you may choose whichever format you like.

=head1 ARCHITECTURE

Morris is a simple IRC bot. Its architecture is loosely depicted below:

                                                -----------------------
                                             ---| Morris::Plugin::Foo |
                    ----------------------   |  -----------------------
                 ---| Morris::Connection |---|--| Morris::Plugin::Bar |
    ----------   |  ----------------------   |  -----------------------
    | Morris |---|                           ---| Morris::Plugin::Baz |
    ----------   |  ----------------------      -----------------------
                 ---| Morris::Connection |...
                    ---------------------- 

What this means is that you can have multiple Morris::Connection objects,
which in turn represent single client-to-server connection. For each
connection, you can define plugins that react to events or do other
intersting stuff with that connection.

For example, if you have a connection to freenode, EFnet, and your own private
IRC server. You can define difference plugin sets for each connection,
and have Morris act differently depending on which connection you are using.

Morris uses a simple plugin mechanism to add extra capabilities (if you're familiar with how Plagger works, it's similar to it).

Plugins are loaded on demand based on the config file specification, and
are initialized with the parameters in the config file. After that, they
are given a chance to register hooks to Morris (actually, Morris::Connection,
since Morris' main features revolve around Morris::Connection, and so plugins are also registered on a per-connection base)

=head1 BASIC CONFIGURATION

Morris expects to have a configuration file with at least the following 
specifications:

    <Config>
      <Connection YourConnectionName>
        Network YourNetworkName
        ... plugins ...
      </Connection>

      <Network YourNetworkName>
        ... network config ...
      </Network>
    </Config>

=head2 Network CLAUSE

The Network clause defines how to connect to a certain IRC network.
Normally you need to set the following fields:

    <Network YourNetworkName>
      Server         irc.freenode.net # the host name to connect to
      Port           6667             # Port number. Defaults to 6667
      Username       YourUsername     # Username to connect as
      Nickname       YourNickname     # Nick name to use
      # If the server is password protected, specify a password
      # Password       YourPassword
    </Network>

The same Network definition may be re-used between multiple Connection
clauses. This will allow multiple bots (if the network allows such thing)

TODO: Need to make Nick/Username configurable

=head2 Connection CLAUSE

The Connection clause defines the actual connection and the plugins that are
supposed to be registered to that connection.

The Connection name is just a symbolic name to differentiate from other
connections, so as long as its unique, you can use whatever you like.

You can skip defining Plugin clauses, but that will just create a bot that
connect to a network, but does nothing.

=head2 Plugin CLAUSE

The Plugin clause is where all the plugins are defined. Multiple plugin
sections are allowed. The order of initialization is NOT guaranteed.

=head1 METHODS

=head2 new(%args)

=head2 new_from_config (\%config)

Instantiate a new morris instance

=head2 run

Starts the servicing.

=head1 AUTHORS

Daisuke Maki C<< <daisuke@endeworks.jp> >> 

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut

