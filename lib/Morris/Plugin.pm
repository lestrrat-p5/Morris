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

__END__

=head1 NAME

Morris::Plugin - Base Class For Morris Plugin

=head1 SYNOPSIS

    package MyPlugin;
    use Moose;
    use namespace::clean -except => qw(meta);

    extends 'Morris::Plugin';

    after register => sub {
        my ($self, $conn) = @_;

        # Do whatever initialization requied

        # Register which hook you want to respond to 
        $conn->register_hook(
            'chat.privmsg',  # hook name
            sub {
                my $msg = shift;
                # Do whatever
            }
        );
    };

=cut
