package Morris::Plugin::Join;
use Moose;
use namespace::clean -except => qw(meta);

extends 'Morris::Plugin';

has channels => (
    traits     => ['Array'],
    is         => 'ro',
    isa        => 'ArrayRef[ArrayRef]',
    lazy_build => 1,
    handles    => {
        all_channels => 'elements',
    }
);

sub _build_channels { [] }

around BUILDARGS => sub {
    my ($next, $class, @args) = @_;
    my $args = $next->($class, @args);

    if (! $args->{channels} ) {
        my $channel = delete $args->{channel};
        $args->{channels} = ref $channel eq 'ARRAY' ? $channel : [ $channel ];
    }

    foreach (@{ $args->{channels} }) {
        $_ = [ split(/\s*,\s*/, $_) ];
    }

    return $args;
};

after register => sub {
    my ($self, $conn) = @_;
    my $join_sub = sub { $self->join_channels(@_) };
    $conn->register_hook( 'server.connected', $join_sub );
};

sub join_channels {
    my $self = shift;

    my $conn = $self->connection;
    $conn->send_srv( JOIN => @$_ ) for $self->all_channels;
}

__PACKAGE__->meta->make_immutable();

1;

