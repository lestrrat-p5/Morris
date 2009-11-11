package Morris::Plugin::QOTD;
use Moose;
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

after setup_dbh => sub {
    my ($self, $dbh) = @_;
    $dbh->exec(<<EOSQL, \&Morris::_noop_cb);
        CREATE TABLE IF NOT EXISTS qotd (
            id integer auto_increment primary key,
            channel text not null,
            quote text not null,
            ends_with_connector BOOLEAN NOT NULL DEFAULT 0,
            created_on integer not null,
            UNIQUE (channel, quote)
        );
EOSQL
    $dbh->commit;
};

sub handle_message {
    my ($self, $msg) = @_;

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
            $self->forget_quote( $msg, $3 );
        } elsif ($3) {
            $self->insert_quote( $msg, $3 );
        } else {
            my $x = $1;
            my $count = scalar(my @a = ($x =~ /\G((?:$command))/g));

            $self->select_quote( $msg, $count );
        }
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

sub forget_quote {
    my ($self, $msg, $quote) = @_;
    my $dbh = $self->get_dbh();
    $dbh->exec(
        "DELETE FROM qotd WHERE channel = ? AND quote = ?",
        $msg->channel,
        $quote,
        sub {
            my $rv = $_[2];
            my $reply = ($rv > 0) ?
                "「$quote」を忘れた！ ($rv)" :
                "「$quote」なんて無かった！"
            ;
            $self->connection->irc_notice({
                channel => $msg->channel,
                message => $reply
            });
        }
    );
}

sub insert_quote {
    my ($self, $msg, $quote) = @_;
    my $ends_with_connector = $self->ends_with_connector($quote);
    my $dbh = $self->get_dbh();
    $dbh->exec(
        "INSERT INTO qotd (channel, quote, ends_with_connector, created_on) VALUES (?, ?, ?, ?)",
        $msg->channel,
        $quote,
        $ends_with_connector,
        time(),
        sub {
            $dbh->exec(
                "SELECT count(*) FROM qotd WHERE channel = ?",
                $msg->channel,
                sub {
                    my $rows = $_[1];
                    $self->connection->irc_notice({
                        channel => $msg->channel,
                        message => "$quote （登録数：$rows->[0]->[0]）",
                    });
                }
            );
        }
    );
}

sub select_quote {
    my ($self, $msg, $count) = @_;

    my $dbh = $self->get_dbh();

    # Do we have any items without a connector?
    $dbh->exec(
        "SELECT quote FROM qotd WHERE channel = ? AND ends_with_connector = 0 ORDER BY random() LIMIT 1",
        $msg->channel,
        sub {
            my ($dbh, $rows, $rv) = @_;
            if (scalar(@$rows) <= 0) {
                # agh, nothing. bail out bail out
                $self->connection->irc_notice({
                    channel => $msg->channel,
                    message => $facemarks[ rand @facemarks ] . " < nothing to see here!"
                })
            } else {
                # proceed
                $self->select_quote_more( $msg, $dbh, $rows->[0]->[0], $count );
            }
        }
    );
}

sub select_quote_more {
    my ($self, $msg, $dbh, $last, $count) = @_;

    if ($count == 1) {
        $self->connection->irc_notice({
            channel => $msg->channel,
            message => $facemarks[ rand @facemarks ] . " < $last"
        });
    } else {
        $dbh->exec(
            "SELECT quote FROM qotd WHERE channel = ? ORDER BY random() LIMIT " . ($count - 1),
            $msg->channel,
            sub {
                my ($dbh, $rows, $rv) = @_;

                return unless $rv;

                $self->connection->irc_notice({
                    channel => $msg->channel,
                    message => $facemarks[ rand @facemarks ] . " < " . join(' ', (map { $_->[0] } @$rows), $last)
                });
            }
        );
    }
}

__PACKAGE__->meta->make_immutable;


1;