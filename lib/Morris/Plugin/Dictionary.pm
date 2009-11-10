package Morris::Plugin::Dictionary;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Morris::Plugin';
with 'Morris::Plugin::WithDB';

has max_definitions => (
    is => 'ro',
    isa => 'Int',
    default => 10,
);

after setup_dbh => sub {
    my ($self, $dbh) = @_;
    $dbh->exec(<<EOSQL, \&Morris::_noop_cb);
        CREATE TABLE IF NOT EXISTS dictionary (
            term TEXT NOT NULL,
            definition TEXT NOT NULL,
            UNIQUE (term, definition)
        );
EOSQL
    $dbh->commit;
};

after register => sub {
    my ($self, $conn) = @_;
    $conn->register_hook( 'chat.privmsg', sub { $self->handle_message(@_) } );
};

sub handle_message {
    my ($self, $msg) = @_;

    my $message = $msg->message;
    my $channel = $msg->channel;
    my $nickname = $self->connection->nickname;
    # <nickname>: XXX=YYYY
    # <nickname>: XXX is YYYY

    # This is to learn new words
    if ($message =~ /^$nickname:\s*([^=]+)\s*=\s*(.+)$/ ||
        $message =~ /^$nickname:\s*(\S+)\s+is\s+(.+)$/
    ) {
        my ($term, $definition) = ($1, $2);
        my $dbh = $self->get_dbh();
        $dbh->exec(
            "SELECT count(*) FROM dictionary WHERE term = ?",
            $term,
            sub {
                my ($dbh, $rows, $rv) = @_;

                my $count = $rows->[0]->[0];
                if ($count > $self->max_definitions) {
                    $self->connection->irc_privmsg({
                        channel => $channel,
                        message => "$term について詰め込みすぎです＞＜。これ以上覚えられません！"
                    });
                } else {
                    $dbh->exec(
                        "INSERT INTO dictionary (term, definition) VALUES (?, ?)",
                        $term,
                        $definition,
                        sub {
                            my @messages = ("らじゃ！", "あいよ！", "はいよー", "うーっす");
                            $self->connection->irc_privmsg({
                                channel => $channel,
                                message => $messages[ rand @messages ]
                            });
                        }
                    );
                }
            }
        )
    } elsif ( $message =~ /^$nickname:\s*([^?]+)\?$/) {
        my $term = $1;
        my $definition;

        my $dbh = $self->get_dbh();
        $dbh->exec(
            "SELECT definition FROM dictionary WHERE term = ?",
            $term,
            sub {
                my ($dbh, $rows, $rv) = @_;

                my @definitions = map { $_->[0] } @$rows;
                my $reply;
                if (! @definitions) {
                    $reply = "$term ってなんですか？おいしい？";
                } else {
                    $reply = "$term は ";
                    if (@definitions == 1) {
                        $reply .= $definitions[0];
                    } else {
                        my $last = pop @definitions;
                        $reply .= join(" 、", @definitions);
                        $reply .= " 、もしくは $last";
                    }
                    $reply .= " ということらしいですYO";
                }
                
                $self->connection->irc_privmsg({
                    channel => $channel,
                    message => $reply,
                });
            }
        );
    }
}

__PACKAGE__->meta->make_immutable();

1;