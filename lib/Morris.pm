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

