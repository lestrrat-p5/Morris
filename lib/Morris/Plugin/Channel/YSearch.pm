package Morris::Plugin::Channel::YSearch;
use Moose;
use URI;
use LWP::UserAgent;
use XML::LibXML;

with 'Morris::Plugin';

has 'appid' => (
    is => 'rw',
    isa => 'Str',
    required => 1
);

has 'user_agent' => (
    is => 'rw',
    isa => 'LWP::UserAgent',
    default => sub { LWP::UserAgent->new(timeout => 10, agent => 'Morris IRCBot/peekURL plugin') },
);

has 'libxml' => (
    is => 'rw',
    isa => 'XML::LibXML',
    default => sub { XML::LibXML->new },
);

__PACKAGE__->meta->make_immutable;

no Moose;


no Moose;

sub register {
    my ($self, $conn) = @_;
    $conn->register_hook( 'channel.public', sub { $self->handle_message(@_) } );
}

sub handle_message {
    my ($self, $args) = @_;

    my $message = $args->{message}->message;
    my $channel = $args->{message}->channel;

    if ( $message =~ m{^\s*!(ysearch)\s+(.+)$} ) {
        my $uri = URI->new('http://search.yahooapis.jp/WebSearchService/V1/webSearch');
        $uri->query_form(
            appid => $self->appid,
            query => $2,
            results => 5
        );
        my $res = $self->user_agent->get($uri);

        my $content = $res->content;
        $content =~ s/xmlns="urn:yahoo:jp:srch" //;
        my $xml = $self->libxml->parse_string($content);
        foreach my $result ($xml->findnodes('/ResultSet/Result')) {
            my $title = $result->findvalue('Title');
            my $uri   = $result->findvalue('Url');
            $self->connection->irc_notice({
                channel => $channel,
                message => "$title - $uri"
            });
        }
    }
}

1;