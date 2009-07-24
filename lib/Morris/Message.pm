# $Id: Message.pm 19289 2008-09-14 09:38:32Z daisuke $

package Morris::Message;
use Moose;
use Moose::Util::TypeConstraints;
use Morris::Client::Address;

class_type 'Morris::Client::Address';

coerce 'Morris::Client::Address'
    => from 'Str'
        => via { Morris::Client::Address->new($_) }
;

no Moose::Util::TypeConstraints; # hide 'from'

has 'from' => (
    is => 'rw',
    isa => 'Morris::Client::Address',
    coerce => 1,
    required => 1,
    handles  => [ qw(modifier nickname username hostname) ]
);

has 'channel' => (
    is => 'rw',
    isa => 'Str',
);

has 'message' => (
    is => 'rw',
    isa => 'Str',
);

has 'timestamp' => (
    is => 'ro',
    isa => 'Int',
    default => sub { time() }
);

__PACKAGE__->meta->make_immutable;

no Moose;

1;