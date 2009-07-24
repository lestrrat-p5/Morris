# $Id$

package Morris::Plugin::Channel::Time;
use Moose;
use DateTime;

with 'Morris::Plugin';

__PACKAGE__->meta->make_immutable;

no Moose;

sub register {
    my ($self, $conn) = @_;
    $conn->register_hook( 'channel.public', sub { $self->handle_message(@_) } );
}

my %WDAY2INDEX = (
    monday => 1,
    tuesday => 2,
    wednesday => 3,
    thursday => 4,
    friday => 5,
    saturday => 6,
    sunday=> 7,
    mon => 1,
    tue => 2,
    wed => 3,
    thu => 4,
    fri => 5,
    sat => 6,
    sun=> 7
);

sub handle_message {
    my ($self, $args) = @_;

    my $message = $args->{message}->message;
    my $channel = $args->{message}->channel;
    my $quote;

    if ( $message =~ m{^\s*!(epoch|time)(?:\s*(\+|next|prev(?:ious)?)\s*(.+))?$} ) {
        my $dt;
        my $type = $1;

        $dt = DateTime->now(time_zone => 'Asia/Tokyo');
        if ($2 eq 'next') {
            my $cur = DateTime->now(time_zone => 'Asia/Tokyo');
            my $x   = $WDAY2INDEX{lc $3};
            return unless defined $x;

            do {
                $cur->add(days => 1);
            } while( $cur->wday != $x );

            $self->connection->irc_notice({
                channel => $channel,
                message => $cur->strftime('%Y-%m-%d (%a)'),
            });
            return;
        }

        if (index($2, 'prev') > -1) {
            my $cur = DateTime->now(time_zone => 'Asia/Tokyo');
            my $x   = $WDAY2INDEX{lc $3};
            return unless defined $x;

            do {
                $cur->subtract(days => 1);
            } while( $cur->wday != $x );

            $self->connection->irc_notice({
                channel => $channel,
                message => $cur->strftime('%Y-%m-%d (%a)'),
            });
            return;
        }

        if ($2 eq '+') {
            my $mode = 'add';
            my $string = $3;
            my ($unit, $amount);
            while ($string =~ /\G\s*(\d+)\s*(year|month|day|hour|min(?:ute)?|sec(?:ond)?)s?/g) {
                ($unit, $amount) = ($2, $1);
                if ($unit eq 'min') {
                    $unit = "minute";
                } elsif ($unit eq 'sec') {
                    $unit = "second";
                }
                $dt->$mode("${unit}s" => $amount);
            }
        } 


        $self->connection->irc_notice({
            channel => $channel,
            message => $type eq 'epoch' ? $dt->epoch : $dt->strftime('%Y-%m-%d %H:%M:%S (%a)')
        });
    }
}

1;