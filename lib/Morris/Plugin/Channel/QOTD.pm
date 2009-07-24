# $Id$

package Morris::Plugin::Channel::QOTD;
use Moose;

with 'Morris::Plugin';

has 'command' => (
    is => 'rw',
    isa => 'Str | RegexpRef',
    default => 'dan'
);

__PACKAGE__->meta->make_immutable;

no Moose;

my @facemarks = (
    '( ´・ω・｀)',
    '(,,ﾟДﾟ)',
    '(´∀｀*)',
    '(・∀・)',
    '(ﾟДﾟ )',
    '＼(^o^)／',
    '(#ﾟДﾟ)',
    '( ´_ゝ｀)∂',
    'ヽ(`Д´)ﾉ',
);

sub register {
    my ($self, $conn) = @_;
    $conn->register_hook( 'channel.public', sub { $self->handle_message(@_) } );
}

sub handle_message {
    my ($self, $args) = @_;

    my $command = $self->command;
    my $message = $args->{message}->message;
    my $channel = $args->{message}->channel;
    my $quote;

    if ( $message =~ m{^
            \s*
            !
            (
                (?:$command)+
            )
            (?:
                :?
                \s+
                (?:
                    (?:
                        (forget\s+)?
                        (.*)
                    )
                    |
                    (?:
                        talk
                    )
                )
            )?
            $}x
     ) {
        # how many?
        my $dbh = DBI->connect('dbi:SQLite:dbname=/service/morris/qotd.db');
        if ($2) {
            $quote = $3;
            my $rv = $dbh->do("DELETE FROM qotd WHERE channel = ? AND quote = ?",
                undef,
                $channel,
                $quote
            );
            if ($rv > 0) {
                $quote = "「$quote」を忘れた！ ($rv)";
            } else {
                $quote = "「$quote」なんて無かった！";
            }
        } elsif ($3) {
            $quote = $3;
            $dbh->do("INSERT INTO qotd (channel, quote, created_on) VALUES (?, ?, ?)", undef, $channel, $quote, time());

            my $sth = $dbh->prepare("SELECT count(*) FROM qotd WHERE channel = ?");
            $sth->execute($channel);
            my ($count) = $sth->fetchrow_array();
            $dbh->disconnect;

            $message .= "（登録数：" . $count . "）";
        } else {
            my $x = $1;
            my $count = scalar(my @a = ($x =~ /\G((?:$command))/g));
            my $sth = $dbh->prepare( "SELECT quote FROM qotd WHERE channel = ? ORDER BY random() LIMIT $count");
            if ($sth->execute($channel)) {
                $quote = '';
                my $a_quote;
                $sth->bind_columns(\$a_quote);
                while ($sth->fetchrow_arrayref) {
                    $quote .= $a_quote . ' ';
                }
            }
            $sth->finish;
            $dbh->disconnect;
        }

        $self->connection->irc_notice({
            channel => $channel,
            message => $facemarks[ rand @facemarks ] . " < $quote ",
        });
    }
}

1;