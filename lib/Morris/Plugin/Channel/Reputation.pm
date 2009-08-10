# $Id: Reputation.pm 34402 2009-07-12 15:21:48Z daisuke $

package Morris::Plugin::Channel::Reputation;
use Moose;
use DBI;

with 'Morris::Plugin';

has connect_info => (
    is => 'ro',
    isa => 'ArrayRef'
);

__PACKAGE__->meta->make_immutable;

no Moose;

sub register {
    my ($self, $conn) = @_;
    $conn->register_hook( 'channel.public', sub { $self->handle_message(@_) } );
}

sub handle_message {
    my ($self, $args) = @_;

    my $channel = $args->{message}->channel;
    my $message = $args->{message}->message;
    my $dbh;

    while ( $message =~ m{(\S+)(--|\+\+)(?:\s+\*\s*(\d+))?}g ) {
        my $who = $1;
        my $action = $2;
        my $add = ($action eq '--' ? -1 : 1) * ($3 || 1);
        
        my ($pluses, $minuses, $score) = (0, 0, 0);

        $dbh ||= $self->get_dbh();

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

sub get_dbh {
    my $self = shift;
    my $connect_info = $self->connect_info();
    $connect_info[3] ||= {};
    if (! exists $connect_info->[3]->{RaiseError} ) {
        $connect_info->[3]->{RaiseError} = 1;
    }
    if (! exists $connect_info->[3]->{AutoCommit} ) {
        $connect_info->[3]->{AutoCommit} = 1;
    }

    my $dbh = DBI->connect(@$connect_info);

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
    return $dbh;
}

1;
