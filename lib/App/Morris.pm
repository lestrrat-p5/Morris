package App::Morris;
use Moose;
use Config::Any;
use Morris;
use namespace::clean -except => qw(meta);

with qw(MooseX::Getopt MooseX::ConfigFromFile);

has '+configfile' => (
    default => '/etc/morris.conf'
);

has config => (
    is => 'ro',
    isa => 'HashRef',
);
    
sub run {
    my $self = shift;

    my $morris = Morris->new_from_config( $self->config );
    $morris->run();
}

sub config_any_args {
    return {
        driver_args => {
            General => {
                -LowerCaseNames => 1
            }
        }
    };
}

sub get_config_from_file {
    my ($class, $file) = @_;

    my $raw_cfany = Config::Any->load_files({
        %{ $class->config_any_args || {} },
        files => [ $file ],
        use_ext => 1,
    });

    die q{Specified configfile '} . $file
        . q{' does not exist, is empty, or is not readable}
            unless $raw_cfany->[0]
                && exists $raw_cfany->[0]->{$file};

    my $raw_config = $raw_cfany->[0]->{$file};
    die "configfile must represent a hash structure"
        unless $raw_config && ref $raw_config && ref $raw_config eq 'HASH';

    $raw_config;
}


__PACKAGE__->meta->make_immutable();

1;