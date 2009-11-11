package Morris::Plugin::Log::DBI;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Morris::Plugin::Log';
with 'Morris::Plugin::WithDB';

sub handle_message {
    my ($self, $args) = @_;

    my $message = $args->{message};

    # make sure this is from the correct channel
    if ($self->should_handle_channel($message)) {
        $self->log_message($args);
        $self->display_log($args);
    }
}

sub display_log {
    my ($self, $message) = @_;
    my $dbh = $self->get_dbh();

    my $body = $message->message;

    if ($body !~ s/^!log\s*(?:\s+(\d+))?$//) {
        return;
    }

    my $limit = $1 || 10;
    my $sql = "SELECT message, nickname, created_on FROM log WHERE channel = ? ORDER BY created_on DESC LIMIT $limit";
    my @binds = ($message->channel);

    $dbh->exec($sql, @binds, sub {
        my ($dbh, $rows, $rv) = @_;

        return unless $rows;
        my $connection = $self->connection;
        foreach my $h (reverse @$rows) {
            $connection->irc_notice({
                channel => $message->channel,
                message => sprintf( '[%s] %s: %s',
                    POSIX::strftime('%Y/%m/%d %T', localtime($h->[2])),
                    $h->[1],
                    $h->[0]
                )
            });
        }
    });
}

after setup_dbh => sub {
    my ($self, $dbh) = @_;
    $dbh->exec(<<EOSQL, \&Morris::_noop_cb);
        CREATE TABLE IF NOT EXISTS log (
            id       INTEGER AUTO_INCREMENT,
            channel TEXT NOT NULL,
            nickname TEXT,
            username TEXT,
            hostname TEXT,
            message  TEXT,
            created_on INTEGER NOT NULL
        );
EOSQL
    $dbh->exec(<<EOSQL, \&Morris::_noop_cb);
        CREATE INDEX IF NOT EXISTS log_created_on_idx ON log (created_on)
EOSQL
    $dbh->exec(<<EOSQL, \&Morris::_noop_cb);
        CREATE INDEX IF NOT EXISTS log_channel_idx ON log (channel)
EOSQL
};

sub log_message {
    my ($self, $message) = @_;

    my $dbh = $self->get_dbh();
    my $sth = $dbh->exec("INSERT INTO log (channel, nickname, username, hostname, message, created_on) VALUES (?, ?, ?, ?, ?, ?)",
        $message->channel,
        $message->from->nickname,
        $message->from->username,
        $message->from->hostname,
        $message->message,
        time(),
        \&Morris::_noop_cb,
    );
}

__PACKAGE__->meta->make_immutable;

1;
