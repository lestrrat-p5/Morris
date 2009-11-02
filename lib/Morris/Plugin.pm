package Morris::Plugin;
use Moose;
use namespace::clean -except => qw(meta);

has connection => (
    is => 'ro',
    isa => 'Morris::Connection',
    writer => '_connection'
);

sub new_from_config {
    my ($class, $args) = @_;
    return $class->new(%$args);
}

sub register {
    my ($self, $conn) = @_;
    $self->_connection( $conn );
    warn "registered $self";
}

__PACKAGE__->meta->make_immutable();

1;
