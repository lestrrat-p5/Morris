# $Id: Reload.pm 19289 2008-09-14 09:38:32Z daisuke $

package Morris::Reload;
use Moose;

has 'stats' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { +{} },
);

no Moose;

sub check
{
    my $self = shift;

    my $c=0;
    while (my($key,$file) = each %INC) {
        next if $file eq $INC{"Morris/Reload.pm"};  #too confusing

        local $^W = 0;

        my $mtime = (stat $file)[9];
        $self->stats->{$file} = $^T
            unless defined $self->stats->{$file};
        if ($mtime > $self->stats->{$file}) {
            delete $INC{$key};
            eval { 
                local $SIG{__WARN__} = \&warn;
                require $key;
            };
            if ($@) {
                warn "Morris::Reload: error during reload of '$key': $@\n"
            }
            ++$c;
        }
        $self->stats->{$file} = $mtime;
    }
    $c;
}

1;
