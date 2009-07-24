# $Id: Address.pm 19289 2008-09-14 09:38:32Z daisuke $

package Morris::Client::Address;
use Moose;

has 'str_ref' => (
    is => 'rw',
    isa => 'ScalarRef',
    required => 1,
    trigger => sub {
        my $self = shift;
        $self->__parsed(0);
    },
);

has '__parsed' => (
    is => 'rw',
    isa => 'Bool',
    required => 1,
    default => 0,
);

has 'modifier' => (
    is => 'rw',
    isa => 'Maybe[Str]',
);

has 'nickname' => (
    is => 'rw',
    isa => 'Maybe[Str]',
);

has 'username' => (
    is => 'rw',
    isa => 'Maybe[Str]',
);

has 'hostname' => (
    is => 'rw',
    isa => 'Maybe[Str]',
);

around 'new' => sub {
    my ($next, $class, @args) = @_;

    if (@args == 1) {
        @args = (str_ref => \$args[0]);
    }
    $next->($class, @args);
};

around qw(modifier nickname username hostname) => \&__check_parsed;

no Moose;

sub __check_parsed {
    my ($next, $self, @args) = @_;

    if (@args) {
        return $next->($self, @args);
    }

    if (! $self->__parsed) {
        my $ref = $self->str_ref;

        $$ref =~ /^(\W)?([^!]+)!([^@]+)@(.*)$/;
        $self->modifier( $1 || '' );
        $self->nickname( $2 || '' );
        $self->username( $3 || '' );
        $self->hostname( $4 || '' );
        $self->__parsed(1);
    }
    return $next->($self);
}


1;
