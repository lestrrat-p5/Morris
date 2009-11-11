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
    traits => ['NoGetopt'],
    is => 'ro',
    isa => 'HashRef',
);

around _usage_format => sub {
    return "usage: %c %o (run 'perldoc App::Morris' for more info)";
};
    
sub run {
    my $self = shift;

    my $morris = Morris->new_from_config( $self->config );
    $morris->run();
    $morris->condvar->recv;
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

__END__

=head1 NAME

App::Morris - Command Line Interface For Morris

=head1 SYNOPSIS

    morris --configfile=/path/to/config.conf

=head1 OPTIONS

=head2 configfile

The location to find the config file. The default is /etc/morris.conf

=cut