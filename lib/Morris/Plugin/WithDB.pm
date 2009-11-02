package Morris::Plugin::WithDB;
use Moose::Role;
use namespace::clean -except => qw(meta);

has dbname => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has _setup_done => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

sub get_dbh {
    my $self = shift;
    my $dbh = $self->connection->get_dbh( $self->dbname );
    if (! $self->_setup_done ) {
        $self->setup_dbh( $dbh );
        $self->_setup_done(1);
    }
    return $dbh;
}

sub setup_dbh { }

1;
