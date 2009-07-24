# $Id: Main.pm 19340 2008-09-15 14:52:47Z daisuke $

package Morris::CLI::Main;
use Moose;
use Config::Any;
use Morris::Engine;

with 'MooseX::Getopt';
with 'MooseX::ConfigFromFile';

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

no Moose;

sub get_config_from_file
{
    my ($class, $file) = @_;

    my $cfg = Config::Any->load_files({
        files => [ $file ],
        use_ext => 1,
        driver_args => {
            General => {
                -LowerCaseNames => 1
            }
        }
    });

    return (scalar @$cfg > 0 && $cfg->[0]->{$file})
        or die "Could not load $file";
}

sub run
{
    my ($self) = @_;
    my $engine = Morris::Engine->new(
        config => $self
    );
    $engine->run();
}

1;