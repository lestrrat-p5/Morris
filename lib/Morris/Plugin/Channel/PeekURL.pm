# $Id$

package Morris::Plugin::Channel::PeekURL;
use Moose;
use HTML::TreeBuilder;
use LWP::UserAgent;
use Image::Size;

with 'Morris::Plugin';

has 'user_agent' => (
    is => 'rw',
    isa => 'LWP::UserAgent',
    default => sub { LWP::UserAgent->new(timeout => 10, agent => 'Morris IRCBot/peekURL plugin') },
);

__PACKAGE__->meta->make_immutable;

no Moose;

sub register {
    my ($self, $conn) = @_;
    $conn->register_hook( 'channel.public', sub { $self->handle_message(@_) } );
}

sub handle_message {
    my ($self, $args) = @_;

    my $message = $args->{message}->message;
    while ( $message =~ m{(!)?(?:(https?):)(?://([^\s/?#]*))([^\s?#]*)(?:\?([^\s#]*))?(?:#(.*))?}g ) {
        my $do_peek = defined($1) ? 0 : 1;
        my ($scheme, $authority, $path, $query, $fragment) = ($2, $3, $4, $5, $6);
        next unless $do_peek;
        next unless $scheme && $scheme =~ /^http/i;
        next unless $authority;

        my $uri = URI->new();
        $uri->scheme($scheme);
        $uri->authority($authority);
        $uri->path($path);
        $uri->query($query);
        $uri->fragment($fragment);

        my $res = $self->user_agent->get($uri);
        if (! $res->is_success ) {
            $self->connection->irc_notice({
                channel => $args->{message}->channel,
                message => $res->message
            });
            next;
        }

        my @ct = $res->content_type;
        if (grep { /^image\/.+$/i } @ct) {
            my($width, $height) = Image::Size::imgsize($res->content_ref);
            $self->connection->irc_notice({
                channel => $args->{message}->channel, 
                message => sprintf( "%s [%s, w=%d, h=%d]", $uri, $res->content_type, $width, $height )
            });
            next;
        }
            
        if ( ! grep { /\btext\/html\b/i } @ct) {
            $self->connection->irc_notice({
                channel => $args->{message}->channel, 
                message => sprintf( "%s [%s]", $uri, $res->content_type )
            });
            next;
        }

        my $p;
        eval { 
            $p = HTML::TreeBuilder->new(
                implicit_tags => 1,
                ignore_unknoown => 1,
                ignore_text => 0
            );
            $p->strict_comment(1);

            my %opts = (
                charset_strict => 1,
                default_charset => 'cp932',
            );

            foreach my $ct (@ct) {
                if ($ct =~ s/charset=Shift_JIS/charset=cp932/) {
                    $res->content_type($ct);
                    $opts{charset} = 'cp932';
                }
            }
            $res->content_type( grep { /^text\//i } @ct );

            if ( my $ref = $res->content_ref ) {
                if ($$ref =~ /charset=(?:'([^']+)'|"([^"]+)"|(.+)\b)/) {
                    my $cs = lc($1 || $2 || $3);
                    if ($cs =~ /^Shift[-_]?JIS$/i) {
                        $opts{charset} = 'cp932';
                    } else {
                        $opts{charset} = $cs;
                    }
                }
            }

            eval {
                $p->parse_content($res->decoded_content(%opts));
            };
            if ($@) {
                # if we got bad content, attempt to decode in order
                foreach my $charset qw(cp932 euc-jp iso-2022-jp utf-8) {
                    eval {
                        $p->parse_content($res->decoded_content(%opts, charset => $charset));
                    };
            
                    last unless $@;
                }
            }
            my ($title) = $p->look_down(_tag => qr/^title$/i);
            $self->connection->irc_notice({
                channel => $args->{message}->channel,
                message => sprintf('%s [%s]', 
                    $title ? $title->as_trimmed_text(skip_dels => 1) || '' : 'No title', $res->content_type || '?')
            });
        };
        if ($@) {
            $self->connection->irc_notice({
                channel => $args->{message}->channel,
                message => sprintf("Error while retrieving URL: %s", $@)
            });
        }
        if ($p) {
            eval { $p->delete }; 
        }
    }
}

1;
