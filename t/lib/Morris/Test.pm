package Morris::Test;
use strict;
use IO::Socket::INET;
use URI;
use Exporter 'import';

our @EXPORT_OK = qw(have_connection);

sub have_connection {
    my $url = URI->new(shift || 'http://www.google.com');
    my $socket = IO::Socket::INET->new(
        PeerAddr => $url->host,
        PeerPort => $url->port
    );

    if (! $socket) {
        return 0;
    } else {
        $socket->close;
        return 1;
    }
}

1;
