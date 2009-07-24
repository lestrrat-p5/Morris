# $Id: Mode.pm 19289 2008-09-14 09:38:32Z daisuke $

package Morris::Plugin::Channel::Mode;
use Moose;

with 'Morris::Plugin';

__PACKAGE__->meta->make_immutable;

no Moose;

sub register { die "not implemented yet" }

1;