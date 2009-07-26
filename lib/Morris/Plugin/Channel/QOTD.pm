# $Id$

package Morris::Plugin::Channel::QOTD;
use Moose;
use DBI;
use Morris::Types;
use Text::MeCab;
use namespace::clean -except => qw(meta);

with 'Morris::Plugin';

has command => (
    is => 'rw',
    isa => 'RegexpRef',
    default => sub { qr/dan/ },
    coerce => 1,
);

has connect_info => (
    is => 'ro',
    isa => 'ArrayRef',
    coerce => 1,
    required => 1,
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

sub register {
    my ($self, $conn) = @_;
    $conn->register_hook( 'channel.public', sub { $self->handle_message(@_) } );

    my $dbh = DBI->connect(@{ $self->connect_info });
    $dbh->{RaiseError} = 1;
    $dbh->do(<<EOSQL);
        CREATE TABLE IF NOT EXISTS qotd (
            id integer auto_increment primary key,
            channel text not null,
            quote text not null,
            ends_with_connector BOOLEAN NOT NULL DEFAULT 0,
            created_on integer not null
        );
EOSQL

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
        my $dbh = DBI->connect(@{ $self->connect_info });
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
            $dbh->disconnect;

            $message .= "（登録数：" . $count . "）";
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

        $dbh->disconnect;
        $self->connection->irc_notice({
            channel => $channel,
            message => $message || $facemarks[ rand @facemarks ] . " < $quote ",
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