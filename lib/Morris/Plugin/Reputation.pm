package Morris::Plugin::Reputation;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Morris::Plugin';
with 'Morris::Plugin::WithDB';

after register => sub {
    my ($self, $conn) = @_;
    $conn->register_hook( 'chat.privmsg', sub { $self->handle_message(@_) } );
};

after setup_dbh => sub {
    my $self = shift;
    my $dbh = $self->get_dbh();
    $dbh->do(<<EOSQL);
CREATE TABLE IF NOT EXISTS reputation (
    id INTEGER AUTO_INCREMENT PRIMARY KEY,
    score INTEGER NOT NULL DEFAULT 0,
    pluses INTEGER NOT NULL DEFAULT 0,
    minuses INTEGER NOT NULL DEFAULT 0,
    nickname TEXT NOT NULL,
    UNIQUE (nickname)
);
EOSQL
    $dbh->commit;
};

sub handle_message {
    my ($self, $msg) = @_;

    my $dbh = $self->get_dbh();
    my $channel = $msg->channel;
    my $message = $msg->message;

    while ( $message =~ m{(\S+)(--|\+\+)(?:\s+\*\s*(\d+))?}g ) {
        my $who = $1;
        my $action = $2;
        my $add = ($action eq '--' ? -1 : 1) * ($3 || 1);
        
        my ($pluses, $minuses, $score) = (0, 0, 0);

        my $sth = $dbh->prepare("SELECT score, pluses, minuses FROM reputation WHERE nickname = ?");
        # fucking DBD::SQLite...
        
        $sth->execute($who);
        ($score, $pluses, $minuses) = $sth->fetchrow_array();
        $sth->finish;

        my $update = (defined $score) ? 1 : 0;
        $score ||= 0;
        $pluses ||= 0;
        $minuses |= 0;

        if ($add > 0) {
            $score += $add;
            $pluses += $add;
        } else {
            $score += $add;
            $minuses += ($add * -1);
        }
        
        my @args = ($score, $pluses, $minuses, $who);
        if ($update) {
            $dbh->do(<<EOSQL, undef, @args);
                UPDATE reputation
                    SET score = ?,
                        pluses = ?,
                        minuses = ?
                WHERE nickname = ?
EOSQL
        } else {
            $dbh->do("INSERT INTO reputation (score, pluses, minuses, nickname) VALUES( ?, ?, ?, ?)", undef, @args);
        }


        $self->connection->irc_notice({
            channel => $channel,
            message => "$who: $score (${pluses}++, ${minuses}--)"
        });
    }
}

__PACKAGE__->meta->make_immutable;

1;