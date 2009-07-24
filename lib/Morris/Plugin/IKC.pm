# $Id: IKC.pm 24704 2008-11-23 14:34:39Z daisuke $

package Morris::Plugin::IKC;
use Moose;
use POE qw(
    Component::IKC::Client
    Component::IKC::Server
);

with 'Morris::Plugin';

has 'session_alias' => (
    is => 'rw',
    isa => 'Str',
    default => 'main_IKC'
);

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

no Moose;

sub register {
    my $self = shift;

    my $server = $self->engine->resource( 'IKCServer' );
    if (! $server) {
        $server = POE::Component::IKC::Server->spawn(
            ip => $self->address,
            port => $self->port,
            name => __PACKAGE__
        );
        $self->engine->set_resource(IKCServer => $server);
    }
    $self->ikc_publish(@_);
}

sub ikc_publish {
    my $self = shift;

    POE::Session->create(
        object_states => [
            $self => {
                map {
                    my $method = $_;
                    $method =~ s/^(?:_)?/poe_/;
                    ($_ => $method)
                } qw(_start _stop notice privmsg)
            }
        ]
    );
}

sub poe_start {
    my ($self, $kernel) = @_[OBJECT, KERNEL];

    $kernel->alias_set($self->session_alias);
    $kernel->post(IKC => publish => $self->session_alias, [ qw(notice privmsg) ]);
}

sub poe_stop {
    my ($self, $kernel) = @_[OBJECT, KERNEL];
    $kernel->alias_remove($self->session_alias);
}

sub poe_notice {
    my ($self, $kernel, $data) = @_[OBJECT, KERNEL, ARG0];

    my ($channel, $message) = @$data;
warn "going to send notice to $channel: $message";
    $self->connection->irc_notice({
        channel => $channel || $self->channel,
        message => $message,
    });
}

sub poe_privmsg {
    my ($self, $kernel, $data) = @_[OBJECT, KERNEL, ARG0];

    my ($channel, $message) = @$data;
    $self->connection->irc_privmsg({
        channel => $channel || $self->channel,
        message => $message,
    });
}

1;
