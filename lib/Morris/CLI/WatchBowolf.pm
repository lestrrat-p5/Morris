package Morris::CLI::WatchBowolf;
use Moose;

with 'MooseX::Getopt';
with 'MooseX::SimpleConfig';

use utf8;
use Digest::MD5 qw(md5_hex);
use DBI;
use Encode qw(decode_utf8 encode_utf8);
use LWP::UserAgent;
use Data::Dumper;
use URI;
use Web::Scraper;
use POE::Component::IKC::ClientLite;

has ikc_address => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has ikc_port => (
    is => 'ro',
    isa => 'Int',
    required => 1
);

has irc_channel => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has connect_info => (
    is => 'ro',
    isa => 'ArrayRef',
    required => 1,
);

has dbh => (
    is => 'ro',
    isa => 'DBI::db',
    lazy_build => 1
);

has scrape_source => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    default => "http://bowolf.tauri.info/"
);

sub _build_dbh {
    my $self = shift;
    my $dbh = DBI->connect( @{ $self->connect_info } );
    $dbh->do(<<EOSQL);
        CREATE TABLE IF NOT EXISTS bowolf_posts (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            title TEXT,
            body TEXT NOT NULL,
            hash CHAR(32) NOT NULL UNIQUE
        );
EOSQL
    return $dbh;
}

sub scrape {
    my $self = shift;
    my $ua = LWP::UserAgent->new();
    my $res = $ua->get( $self->scrape_source );
    if (! $res->is_success ) {
        confess "Failed to get " . $self->scrape_source;
    }

    my $scraper = scraper {
        process "div.list" => "posts[]" => scraper {
            process 'li[class = "t"]' => "title" => "TEXT";
            process 'li[class != "t"]' => "name" => "TEXT";
            process 'p' => "body" => "TEXT";
        }
    };

    return $scraper->scrape( $res->decoded_content );
}

sub run {
    my $self = shift;
    my $result = $self->scrape();

    foreach my $post (@{ $result->{posts} }) {
        $post->{name} =~ s/^名前://;
        foreach my $col qw(title name body) {
            $post->{$col} = encode_utf8($post->{$col});
        }
        if (! $self->save_if_new( $post ) ) {
            next;
        }

        $self->post_ikc( $post );
    }
}

sub save_if_new {
    my ($self, $post) = @_;

    my $hash = md5_hex($post->{title}, $post->{name}, $post->{body});

    my $dbh = $self->dbh;
    my $sth = $dbh->prepare_cached("SELECT id FROM bowolf_posts WHERE hash = ?");
    my $rv = $sth->execute($hash);
    if ($sth->fetchrow_arrayref) {
        $sth->finish;
        return ();
    }
    $sth->finish;

    $sth = $dbh->prepare_cached("INSERT INTO bowolf_posts (name, title, body, hash) VALUES (?, ?, ?, ?)");
    $sth->execute( $post->{name}, $post->{title}, $post->{body}, $hash );
    $sth->finish;
}

sub post_ikc {
    my ( $self, $post ) = @_;
    my $poe = create_ikc_client(
        ip => $self->ikc_address,
        port => $self->ikc_port,
    );
    die POE::Component::IKC::ClientLite::error() unless $poe;

    $poe->post("main_IKC/notice",
        [
            sprintf('#%s', $self->irc_channel),
            sprintf('【ボ狼】 %s の書き込み「%s」がありました: http://tinyurl.com/bowolf',
                decode_utf8($post->{name}),
                decode_utf8($post->{title}) || '無題',
            )
        ]
    ) or die $poe->error;

    $poe->disconnect;
}

sub DEMOLISH {
    my $self = shift;
    $self->dbh->disconnect;
}

1;
