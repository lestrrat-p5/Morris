# $Id: Werewolf.pm 29743 2009-02-09 03:22:23Z daisuke $

package Morris::Plugin::Game::Werewolf;
use Moose;
use Game::Werewolf;

with 'Morris::Plugin';

has 'game' => (
    is => 'rw',
    isa => 'Game::Werewolf',
    lazy_build => 1,
    required => 1,
);

__PACKAGE__->meta->make_immutable;

no Moose;

sub register {
    my ($self, $conn) = @_;

    $conn->register_hook( 'channel.public', sub { $self->handle_message(@_) } );
}

sub _build_game {
    return Game::Werewolf->new(
        
    );
}

sub handle_message {
    my ($self, $args) = @_;

    my $message = $args->{message};
    my $body    = $message->message;

    if ($body =~ /^!wolf(?::\s*|\s+)(.+)$/) {
        my $command = $1;
        $self->handle_command({
            message => $message,
            command => $1
        });
    }
}

sub handle_command {
    my ($self, $args) = @_;

    my $command = $args->{command};
    my $connection = $self->connection;
    my $message = $args->{message};
    if ($command eq 'start') {
        $connection->irc_privmsg({
            channel => $message->channel,
            message => "人狼開始リクエストを受け取りました"
        });

        my $output = '';
        my $game = $self->game;
        $game->reset;
        $game->players_add(
            Game::Werewolf::Player->new(name => $message->from->nickname)
        );

        $self->send_status( { channel => $message->channel } );
    } elsif ($command eq 'status') {
        $self->send_status( { channel => $message->channel } );
    } elsif ($command eq 'join') {
        my $game = $self->game;
        if ($game->started) {
            $connection->irc_privmsg({
                channel => $message->channel,
                message => "ゲーム参加は現在受け付けていません"
            });
        } else {
            eval {
                $game->players_add(
                    Game::Werewolf::Player->new(name => $message->from->nickname)
                );
            };
            if ($@) {
                $connection->irc_privmsg({
                    channel => $message->channel,
                    message => $message->from->nickname . " :すでに登録されています"
                });
            } else {
                $self->send_status( { channel => $message->channel } );
            }
        }
    }
}

sub send_status {
    my ($self, $args) = @_;
    my $channel = $args->{channel};
    my $connection = $self->connection;

    my $output = '';
    $self->game->status(\$output);
    $connection->irc_notice({
        channel => $channel,
        message => $_,
    }) for split /\r?\n/, $output;
}

1;