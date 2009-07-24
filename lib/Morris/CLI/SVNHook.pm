# $Id$

package Morris::CLI::SVNHook;
use Moose;
use POE::Component::IKC::ClientLite;

with 'MooseX::Getopt';

has 'address' => (
    is => 'rw',
    isa => 'Str',
    default => '127.0.0.1',
);

has 'port' => (
    is => 'rw', 
    isa => 'Int',
    default => 12321
);

has 'channel' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has 'prefix' => (
    is => 'rw',
    isa => 'Str',
    default => 'SVN commit'
);

has 'revision' => (
    is => 'rw',
    isa => 'Int',
    required => 1,
);

has 'depot' => (
    is => 'rw',
    isa => 'Str',
    required => 1
);

has 'message' => (
    is => 'rw',
    isa => 'Str',
    required => 1
);

has 'author' => (
    is => 'rw',
    isa => 'Str',
    required => 1
);

__PACKAGE__->meta->make_immutable;

no Moose;

sub run {
    my $self = shift;

    my $poe = create_ikc_client(
        ip => $self->address,
        port => $self->port,
    );
    die POE::Component::IKC::ClientLite::error() unless $poe;

    $poe->post("main_IKC/notice",
        [
            sprintf('#%s', $self->channel),
            sprintf('%s [%d] %s: %s (%s)',
                $self->prefix,
                $self->revision,
                $self->depot,
                $self->message,
                $self->author
            )
        ]
    ) or die $poe->error;
    
    $poe->disconnect;
}


__END__

=head1 NAME

Morris::CLI::SVNHook - Grab Updates From Subversion

=head1 SYNOPSIS

    morris_svn_hook.pl 
        --ikc_server=...
        --ikc_port=...
        --channel=channel
        --revision=...
        --depot=...
        --message=...
        --committer=

=cut