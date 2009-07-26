package Morris::Plugin::Channel::Dictionary;
use Moose;
use Moose::Util::TypeConstraints;
use DBI;
use namespace::clean -except => qw(meta);

with 'Morris::Plugin';

coerce 'ArrayRef'
    => from 'Str'
    => via { [ $_ ] }
;
has connect_info => (
    is => 'ro',
    isa => 'ArrayRef',
    coerce => 1,
    required => 1
);

has max_definitions => (
    is => 'ro',
    isa => 'Int',
    default => 10,
);

sub register {
    my ($self, $conn) = @_;
    $conn->register_hook( 'channel.public', sub { $self->handle_message(@_) } );

    my $dbh = DBI->connect(@{ $self->connect_info });
    $dbh->do(<<EOSQL);
        CREATE TABLE IF NOT EXISTS dictionary (
            term TEXT NOT NULL,
            definition TEXT NOT NULL,
            UNIQUE (term, definition)
        );
EOSQL
    $dbh->commit;
}

sub handle_message {
    my ($self, $args) = @_;

    my $message = $args->{message}->message;
    my $channel = $args->{message}->channel;
    my $nickname = $self->connection->nickname;
    # <nickname>: XXX=YYYY
    # <nickname>: XXX is YYYY

    # This is to learn new words
    if ($message =~ /^$nickname:\s*([^=]+)\s*=\s*([\S.]+)$/ ||
        $message =~ /^$nickname:\s*(\S+)\s+is\s+([\S.]+)$/
    ) {
        my ($term, $definition) = ($1, $2);
        my $dbh = DBI->connect(@{ $self->connect_info });

        my $sth;

        $sth = $dbh->prepare("SELECT count(*) FROM dictionary WHERE term = ?");
        $sth->execute($term);
        my ($count) = $sth->fetchrow_array();
        $sth->finish;

        if ($count > $self->max_definitions) {
            $self->connection->irc_privmsg({
                channel => $channel,
                message => "$term について詰め込みすぎです＞＜。これ以上覚えられません！"
            });
        } else {
            $dbh->do("INSERT INTO dictionary (term, definition) VALUES (?, ?)", undef, $term, $definition);

            my @messages = ("らじゃ！", "あいよ！", "はいよー", "うーっす");
            $self->connection->irc_privmsg({
                channel => $channel,
                message => $messages[ rand @messages ]
            });
        }
    } elsif ( $message =~ /^$nickname:\s*([^?]+)\?$/) {
        my $term = $1;
        my $dbh = DBI->connect(@{ $self->connect_info });
        my $definition;

        my $sth = $dbh->prepare("SELECT definition FROM dictionary WHERE term = ?");
        $sth->execute($term);
        $sth->bind_columns(\$definition);
        my @definition;
        while ($sth->fetchrow_arrayref) {
            push @definition, $definition;
        }

        my $reply;
        if (! @definition) {
            $reply = "$term ってなんですか？おいしい？";
        } else {
            $reply = "$term は ";
            if (@definition == 1) {
                $reply .= $definition[0];
            } else {
                my $last = pop @definition;
                $reply .= join(" 、", @definition);
                $reply .= " 、もしくは $last";
            }
            $reply .= " ということらしいですYO";
        }
                
        $self->connection->irc_privmsg({
            channel => $channel,
            message => $reply,
        });
    }
}

__PACKAGE__->meta->make_immutable();

1;