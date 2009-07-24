# $Id: Plugin.pm 24702 2008-11-23 14:12:32Z daisuke $

package Morris::Plugin;
use Moose::Role;

has 'connection' => (
    is       => 'rw',
    isa      => 'Morris::Connection',
    required => 1,
    handles  => [ qw(engine) ],
);

requires qw(register);

no Moose::Role;

1;