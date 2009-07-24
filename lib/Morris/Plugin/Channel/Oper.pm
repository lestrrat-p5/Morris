package Morris::Plugin::Channel::Oper;

use Moose;

with 'Morris::Plugin';

has 'channel' => (
    is  => 'rw',
    isa => 'Maybe[Str]',
);

has 'users' => (
    is         => 'rw',
    isa        => 'ArrayRef[Str]',
    auto_deref => 1,
    default    => sub { +[] },
);

around 'new' => sub {
    my $next  = shift;
    my $class = shift;
    my %args  = @_;

    if (! $args{users} && $args{user}) {
        my $user = delete $args{user};
        $args{users} = ref $user eq 'ARRAY' ? $user : [ $user ];
    }

    $next->($class, %args);
};  

__PACKAGE__->meta->make_immutable;

no Moose;

sub register {
    my ($self, $conn) = @_;
    $conn->register_hook( 'channel.join', sub { $self->handle_message(@_) } );
}

sub handle_message {
    my ($self, $args) = @_;

    my $channel = $self->channel;
    my $who     = $args->{message}->from;
    my $id      = ${ $who->str_ref };
    my $where   = $args->{message}->channel;

    if ($channel) {
        return () unless $channel eq $where;
    }

    if ( grep { $id =~ /$_/ } $self->users ) {
        $self->connection->irc_notice({
            channel => $where,
            message => join(" ", "Hello,", $who->nickname, "!" )
        });
        $self->connection->irc_mode({
            channel => $where,
            mode    => '+o',
            who     => $who->nickname,
        });
    }
}

1;
