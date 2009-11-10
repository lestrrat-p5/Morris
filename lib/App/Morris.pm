package App::Morris;
use Moose;
use Config::Any;
use Morris;
use namespace::clean -except => qw(meta);

with qw(MooseX::Getopt MooseX::SimpleConfig);

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


__PACKAGE__->meta->make_immutable();

1;