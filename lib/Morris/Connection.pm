# $Id: Connection.pm 28165 2009-01-08 06:40:53Z daisuke $

package Morris::Connection;
use Moose;
use Moose::Util::TypeConstraints;
use Morris::Message;
use POE qw(Component::IRC Component::IRC::Plugin::Connector Component::IRC::Plugin::BotCommand);
use Data::Dumper;

has 'alias' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    lazy => 1,
    builder  => 'build_alias',
);

has 'session' => (
    is => 'rw',
    isa => 'POE::Session',
);

has 'irc' => (
    is => 'rw',
    isa => 'POE::Component::IRC'
);

has 'hooks' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { +{} }
);

has 'server' => (
    is => 'rw',
    isa => 'Str',
    required => 1
);

has 'port' => (
    is => 'rw',
    isa => 'Str',
    default => 6667,
    required => 1
);

has 'nickname' => (
    is => 'rw',
    isa => 'Str',
    required => 1
);

has 'password' => (
    is => 'rw',
    isa => 'Str',
);

has 'plugins' => (
    is => 'rw',
    isa => 'HashRef',
    coerce => 1,
    default => sub { +{} },
);

has 'bot' => (
    is => 'rw',
    isa => 'POE::Component::IRC::Plugin::BotCommand'
);

has 'engine' => (
    is => 'rw',
    isa => 'Morris::Engine',
    required => 1,
    handles  => [ qw(resource set_resource) ],
);

__PACKAGE__->meta->make_immutable;

no Moose;
no Moose::Util::TypeConstraints;

$Data::Dumper::Indent   = 1;
$Data::Dumper::Terse    = 1;
$Data::Dumper::Sortkeys = 1;

sub BUILDARGS {
    my ($self, %args) = @_;

    $args{plugins} = delete $args{plugin};
    return \%args;
}

sub BUILD {
    my ($self, $args) = @_;

    my $plugins = $self->plugins;
    while (my ($plugin_class, $config) = each %$plugins) {
print "plugin: $plugin_class\n";
        if ($plugin_class !~ s/^\+//) {
            $plugin_class = "Morris::Plugin::$plugin_class";
        }
        Class::MOP::load_class($plugin_class);

        my @args;
        if ( ref $config eq 'ARRAY') {
            @args = @$config;
        } else {
            @args = ($config);
        }

        foreach my $args (@args) {
            my $plugin = $plugin_class->new(%$args, connection => $self);
            $plugin->register( $self );
        }
    }

    $self;
}

sub bot_alias { join('-', shift->alias, 'bot') }
sub build_alias { join('-', 'blah', $$, {}, time(), rand() ) }


sub start
{
    my $self = shift;
    my %states = (
        map {
            my $k = $_;
            $k =~ s/^_?/poe_/;
            ($_ => $k)
        } (
            qw( _start _stop call_hook connect ),
            qw( irc_registered irc_001 irc_002 irc_003 irc_socketerr irc_disconnected ),
            qw( irc_public irc_join),
            qw( periodic ),
        )
    );

    $self->session(
        POE::Session->create(
            object_states => [
                $self => \%states
            ]
        )
    );
}

sub register_hook {
    my ($self, $name, $code) = @_;

    $self->hooks->{$name} ||= [];
    my $list = $self->hooks->{$name};
    push @$list, $code;
}

sub register_command {
    my ($self, $cmd, $usage, $code) = @_;
    $self->bot->add( $cmd, $usage, $code );
}

sub poe_start {
    my ($self, $kernel) = @_[ OBJECT, KERNEL ];

    $kernel->alias_set( $self->alias );
    my $irc = POE::Component::IRC->spawn(
        alias    => $self->bot_alias,
        $ENV{MORRIS_CONNECTION_DEBUG} ? (
            debug => 1,
            options  => { debug => 1, trace => 1 },
        ) : ()
    );
    $irc->plugin_add( Connector => POE::Component::IRC::Plugin::Connector->new() );
    my $bot = POE::Component::IRC::Plugin::BotCommand->new();
    $self->bot($bot);
    $irc->plugin_add('BotCommand' => $bot);

    $self->irc($irc);

    $kernel->delay( periodic => 10 );

#    $irc->yield( register => 'all' );

    $kernel->post($self->alias, 'connect') or die;
}

sub poe_periodic {
    my ($self, $kernel) = @_[OBJECT, KERNEL];

    $self->call_hook( 'periodic' );
    $kernel->delay( periodic => 10 );
}
        

sub poe_connect {
    my $self = $_[OBJECT];

    my $irc = $self->irc;
    $irc->yield( connect  => {
        nick     => $self->nickname,
        server   => $self->server,
        port     => $self->port,
        password => $self->password,
    } );
}

sub poe_stop
{
    my ($self, $kernel) = @_[ OBJECT, KERNEL ];

    $kernel->alias_remove( $self->alias );
    $self->irc->shutdown();
}

sub poe_call_hook
{
    my ($self, $kernel, $name) = @_[ OBJECT, KERNEL, ARG0 ];

    $self->call_hook($name);
}

sub call_hook
{
    my ($self, $name, @args) = @_;

    my $hooks = $self->hooks->{$name};
    return unless $hooks;

    foreach my $hook (@$hooks) {
        $hook->( @args );
    }
}

sub log {
    my ($self, @args) = @_;
    printf STDERR @args;
}

sub poe_irc_registered {
    my ($self, $kernel) = @_[ OBJECT, KERNEL ];

    my $irc = $self->irc;
    $self->log( 
        "Connecting to %s:%s as %s (USING password %s)\n", 
        $self->server,
        $self->port,
        $self->nickname,
        $self->password ? "YES" : "NO"
    );
}

sub poe_irc_socketerr {
    my ($self, $kernel, $errstr) = @_[ OBJECT, KERNEL, ARG0 ];
    $self->log( "Connect failed: %s\n", $errstr);
}

sub poe_irc_001 {
    my ($self, $kernel, $server, $message) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
    $self->log( "Connected to %s: %s\n", $server, $message );
    $self->call_hook( 'server.welcome', server => $server, message => $message );
    $self->call_hook( 'server.connected' );
}

sub poe_irc_002 {
    my ($self, $kernel, $host, $message) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
    $self->call_hook( 'server.yourhost', host => $host, message => $message );
}

sub poe_irc_003 {
    my ($self, $kernel, $host, $message) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
    $self->call_hook( 'server.003', host => $host, message => $message );
    
}

sub poe_irc_public {
    my ($self, $who, $where, $what) = @_[ OBJECT, ARG0 .. ARG2 ];

#    if ($what =~ /!morris (on|off)$/) {
#        $self->enabled
    $self->call_hook(
        'channel.public',
        {
            message => Morris::Message->new(
                from    => $who,
                channel => $where->[0],
                message => $what,
            )
        }
    );
}

sub poe_irc_join {
    my ($self, $who, $where ) = @_[ OBJECT, ARG0, ARG1 ];

    $self->call_hook(
        'channel.join',
        {
            message => Morris::Message->new(
                from    => $who,
                channel => $where,
            )
        }
    );
}

sub poe_irc_disconnected {
    my ($self, $where) = @_[ OBJECT, ARG0 ];
    $self->log(  "Disconnected from %s\n", $where );
}

sub irc_join
{
    my ($self, $args) = @_;

    my $channels = $args->{channels};

    my $irc = $self->irc;
    foreach my $channel (@$channels) {
        my ($name, $password) = ref ($channel) eq 'ARRAY' ? @$channel : ($channel, undef);
        $self->log( "Joined channel '%s'\n", $name );
        $irc->yield( join => $name => $password );
    }
}

sub irc_mode
{
    my ($self, $args) = @_;

    my $irc = $self->irc;

    $irc->yield( 'mode' => $args->{channel} => $args->{mode} => $args->{who} );
}

sub irc_privmsg {
    my ($self, $args) = @_;

    my $irc = $self->irc;

    $irc->yield( privmsg => $args->{channel} => $args->{message} );
}

sub irc_notice {
    my ($self, $args) = @_;

    my $irc = $self->irc;

    $irc->yield( notice => $args->{channel} => $args->{message} );
}

1;
