# $Id$

package Morris::Plugin::Channel::Log::DBI;
use Moose;
use DBI;
use SQL::Abstract::Limit;

with 'Morris::Plugin::Channel::Log';

has 'connect_info' => (
    is => 'rw',
    isa => 'ArrayRef',
    auto_deref => 1,
    required => 1
);

has 'table_created' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

has 'dbhandle' => (
    is => 'rw',
    isa => 'DBI::db',
    lazy => 1,
    builder => 'build_dbhandle'
);

has 'sqla' => (
    is => 'rw',
    isa => 'SQL::Abstract::Limit',
    lazy => 1,
    builder => 'build_sqla'
);

__PACKAGE__->meta->make_immutable;

no Moose;

sub BUILDARGS {
    my ($class, %args) = @_;

    my $dsn = delete $args{dsn};
    my $user = delete $args{user};
    my $password = delete $args{password};
    return { %args, connect_info => [ $dsn, $user, $password, { RaiseError => 1, AutoCommit => 1 } ] };
}

sub build_dbhandle {
    my $self = shift;
    return DBI->connect($self->connect_info);
}

sub build_sqla {
    my $self = shift;
    my $dbh = $self->dbhandle;
    return SQL::Abstract::Limit->new( limit_dialect => $dbh );
}

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
    my ($self, $args) = @_;
    my $dbh = $self->dbhandle;

    my $message = $args->{message};
    my $body = $message->message;

    my $myname = $self->connection->nickname;
    if ($body !~ s/^$myname:\s*log(?:\s+(\d+))?$//) {
        return;
    }

    my $limit = $1 || 10;
    my $sqla = $self->sqla;
    my ($sql, @binds) = $sqla->select(
        'log',
        '*',
        { channel => $message->channel },
        [ 'created_on DESC' ],
        $limit
    );

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

sub log_message {
    my ($self, $args) = @_;

    my $dbh = $self->dbhandle;
    if ( ! $self->table_created ) {
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
        $dbh->do(<<EOSQL);
            CREATE INDEX IF NOT EXISTS log_channel ON log (channel);
EOSQL
        $dbh->do(<<EOSQL);
            CREATE INDEX IF NOT EXISTS log_nickname ON log (nickname);
EOSQL
        $dbh->do(<<EOSQL);
            CREATE INDEX IF NOT EXISTS log_username ON log (username);
EOSQL
        $dbh->do(<<EOSQL);
            CREATE INDEX IF NOT EXISTS log_hostname ON log (hostname);
EOSQL
        $dbh->do(<<EOSQL);
            CREATE INDEX IF NOT EXISTS log_message ON log (message);
EOSQL
        $dbh->do(<<EOSQL);
            CREATE INDEX IF NOT EXISTS log_created_on ON log (created_on);
EOSQL
        
        $self->table_created(1);
    }

    my $message = $args->{message};
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

1;