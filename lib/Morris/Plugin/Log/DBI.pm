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

    my $myname = $self->connection->nickname;
    if ($body !~ s/^$myname:\s*log(?:\s+(\d+))?$//) {
        return;
    }

    my $limit = $1 || 10;
    my $sql = "SELECT * FROM log WHERE channel = ? LIMIT $limit ORDER BY created_on DESC";
    my @binds = ($message->channel);

    my $sth = $dbh->prepare($sql);
    $sth->execute(@binds);
    my $connection = $self->connection;
    my @logs;
    while( my $h = $sth->fetchrow_hashref ) {
        push @logs, $h;
    }

    foreach my $h (reverse @logs) {
        $connection->irc_notice({
            channel => $message->channel,
            message => sprintf( '[%s] %s: %s',
                POSIX::strftime('%Y/%m/%d %T', localtime($h->{created_on})),
                $h->{nickname},
                $h->{message}
            )
        });
    }
}

after setup_dbh => sub {
    my ($self, $dbh) = @_;
    $dbh->do(<<EOSQL);
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
};

sub log_message {
    my ($self, $message) = @_;

    my $dbh = $self->get_dbh();

    my $sth = $dbh->prepare("INSERT INTO log (channel, nickname, username, hostname, message, created_on) VALUES (?, ?, ?, ?, ?, ?)");
    $sth->execute(
        $message->channel,
        $message->from->nickname,
        $message->from->username,
        $message->from->hostname,
        $message->message,
        time()
    );
}

__PACKAGE__->meta->make_immutable;

1;
