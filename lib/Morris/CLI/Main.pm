package Morris::CLI::Main;
use Moose;
use Morris::Engine;
use namespace::clean -except => qw(meta);

with 'MooseX::Getopt';
with 'MooseX::SimpleConfig';

has '+configfile' => (
    default => '/etc/morris.conf'
);

has 'connection' => (
    is => 'rw',
    isa => 'HashRef'
);

has 'network' => (
    is => 'rw',
    isa => 'HashRef'
);

__PACKAGE__->meta->make_immutable;

sub run
{
    my ($self) = @_;
    my $engine = Morris::Engine->new(
        config => $self
    );
    $engine->run();
}

1;