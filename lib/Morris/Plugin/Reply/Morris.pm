# $Id$

package Morris::Plugin::Reply::Morris;
use Moose;

with 'Morris::Plugin';

__PACKAGE__->meta->make_immutable;

no Moose;

sub register {
    my ($self, $conn) = @_;
    $conn->register_hook( 'channel.public', sub { $self->process(@_) } );
}

sub process {
    my ($self, $args) = @_;

    my $message = $args->{message};
    my $body = $message->message;
    $body =~ s/^morris:\s*// or return;

    if ($body =~ /^history(?:\s+(today)|(yesterday)|(?:(\d\d\d\d)[-\s])?(\d?\d)[-\s](\d?\d))/) {
        if ($1) { # today
            $dt = DateTime->today()->strftime('%Y-%m-%d');
        } elsif($2) {
            $dt = DateTime->today->subtract(days => 1)->strftime('%Y-%m-%d');
        } else {
            my $today = DateTime->today();
            my $year  = $3 || $today->year;
            my $month = $4;
            my $day   = $5;

            $dt = join('-', $year, $month, $day);
        }

        if ( -f 
    }
}

1;

