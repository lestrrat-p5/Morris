package Morris::Plugin::QOTD;
use Moose;
use DBI;
use Text::MeCab;
use namespace::clean -except => qw(meta);

extends 'Morris::Plugin';
with 'Morris::Plugin::WithDB';

has command => (
    is => 'rw',
    isa => 'RegexpRef',
    default => sub { qr/dan/ },
    coerce => 1,
);

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

after register => sub {
    my ($self, $conn) = @_;
    $conn->register_hook( 'chat.privmsg', sub { $self->handle_message(@_) } );
};

sub handle_message {
    my ($self, $msg) = @_;

    my $dbh = $self->get_dbh();
    $dbh->do(<<EOSQL);
        CREATE TABLE IF NOT EXISTS qotd (
            id integer auto_increment primary key,
            channel text not null,
            quote text not null,
            ends_with_connector BOOLEAN NOT NULL DEFAULT 0,
            created_on integer not null
        );
EOSQL

    my $command = $self->command;
    my $message = $msg->message;
    my $channel = $msg->channel;
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
        my $reply;
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
            my $ends_with_connector = $self->ends_with_connector($quote);
            $dbh->do("INSERT INTO qotd (channel, quote, ends_with_connector, created_on) VALUES (?, ?, ?, ?)", undef, $channel, $quote, $ends_with_connector, time());

            my $sth = $dbh->prepare("SELECT count(*) FROM qotd WHERE channel = ?");
            $sth->execute($channel);
            my ($count) = $sth->fetchrow_array();
            $reply = "$message （登録数：$count）";
        } else {
            my $x = $1;
            my $count = scalar(my @a = ($x =~ /\G((?:$command))/g));

            my $last = $dbh->prepare( "SELECT quote FROM qotd WHERE channel = ? AND ends_with_connector = 0 ORDER BY random() LIMIT 1");
            if ($count == 1) {
                $last->execute($channel);
                ($quote) = $last->fetchrow_array();
                $last->finish;
            } else {
                my $sth = $dbh->prepare( "SELECT quote FROM qotd WHERE channel = ? ORDER BY random() LIMIT " . ($count - 1));
                if ($sth->execute($channel)) {
                    $quote = '';
                    my $a_quote;
                    $sth->bind_columns(\$a_quote);
                    while ($sth->fetchrow_arrayref) {
                        $quote .= $a_quote . ' ';
                    }
                    $last->execute($channel);
                    $quote .= ($last->fetchrow_array)[0];
                    $last->finish;
                }
                $sth->finish;
            }
        }

        $quote ||= '...';
        $self->connection->irc_notice({
            channel => $channel,
            message => $reply || $facemarks[ rand @facemarks ] . " < $quote ",
        });
    }
}

sub ends_with_connector {
    my ($self, $quote) = @_;
    my $mecab = Text::MeCab->new();

    my $ret = 0;
    my $prev;
    for( my $node = $mecab->parse($quote); $node; $node = $node->next ) {
        my $type = (split /,/, $node->feature)[0];
        if ($type =~ /[EB]OS/ && ($prev eq '接続詞' || $prev eq '助詞')) {
            $ret = 1;
        }
        $prev = $type;
    }
    return $ret;
}

__PACKAGE__->meta->make_immutable;


1;