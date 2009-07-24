# $Id$

package Morris::Bot;
use Moose;

extends 'POE::Component::IRC::Plugin::BotCommand';

__PACKAGE__->meta->make_immutable;

no Moose;

sub S_public {
    my ($self, $irc) = splice @_, 0, 2;
    my $who = ${ $_[0] };
    my $channel = ${ $_[1] };
    my $what = ${ $_[2] };
    my $me = $irc->nick_name();

    if ($self->{Addressed}) {
        return PCI_EAT_NONE if !(($what) = $what =~ m/^\s*\Q$me\E[\:\,\;\.\~]?\s*(.*)$/);
    }
    else {
        return PCI_EAT_NONE if $what !~ s/^$self->{Prefix}//;
    }

    my ($cmd, $args);
    if (!(($cmd, $args) = $what =~ /^(\w+)(?:\s+(.+))?$/)) {
        return PCI_EAT_NONE;
    }
    
    $cmd = lc $cmd;
    if (exists $self->{Commands}->{$cmd}) {
        $irc->send_event("irc_botcmd" => $who, $channel, $args);
    }
    
    return $self->{Eat} ? PCI_EAT_PLUGIN : PCI_EAT_NONE;
}

sub add {
    my ($self, $cmd, $usage, $code) = @_;

