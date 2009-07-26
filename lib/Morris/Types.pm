package Morris::Types;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::clean -except => qw(meta);

coerce 'ArrayRef'
    => from 'Str'
    => via { [ $_ ] }
;

coerce 'RegexpRef'
    => from 'Str'
    => via { qr/$_/ }
;

1;
