package Morris::Plugin::YSearch;
use Moose;
use AnyEvent::HTTP;
use Encode qw(encode_utf8);
use File::Temp;
use URI;
use XML::LibXML;
use namespace::clean -except => qw(meta);

extends 'Morris::Plugin';

has appid => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has libxml => (
    is => 'ro',
    isa => 'XML::LibXML',
    lazy_build => 1,
);

sub _build_libxml { XML::LibXML->new }

after register => sub {
    my ($self, $conn) = @_;
    $conn->register_hook( 'chat.privmsg', sub { $self->handle_message(@_) } );
};

sub handle_message {
    my ($self, $msg) = @_;

    my $message = $msg->message;
    my $channel = $msg->channel;

    if ( $message =~ m{^\s*!(ysearch)\s+(.+)$} ) {
        my $uri = URI->new('http://search.yahooapis.jp/WebSearchService/V1/webSearch');
        $uri->query_form(
            appid => $self->appid,
            query => $2,
            results => 5
        );

        my $file;
        http_get $uri,
            on_header => sub {
                return $_[0]->{Status} eq '200';
            },
            on_body => sub {
                $file ||= File::Temp->new(UNLINK => 1);
                print $file $_[0];
            },
            sub {
                seek($file, 0, 0);

                my $xml = $self->libxml->parse_fh($file);
                $xml->getDocumentElement->setNamespaceDeclPrefix('' => 'default');
                my $xpc = XML::LibXML::XPathContext->new($xml);
#                $xpc->registerNs('default', "urn:yahoo");

                foreach my $result ($xpc->findnodes('/default:ResultSet/default:Result')) {
                    my $title = $result->findvalue('default:Title');
                    my $uri   = $result->findvalue('default:Url');
                    $self->connection->irc_notice({
                        channel => $channel,
                        message => encode_utf8("$title - $uri"),
                    });
                }
                undef $file;
            }
    }
}

__PACKAGE__->meta->make_immutable;

1;
