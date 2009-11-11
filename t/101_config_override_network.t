use strict;
use lib "lib";
use Test::More (tests => 2);
use App::Morris;

local @ARGV = qw(--configfile t/101_config_override_network.conf);
my $app = App::Morris->new_with_options();

my $morris = Morris->new_from_config( $app->config );

is( $morris->connections->[0]->nickname, 'overridden' );
is( $morris->connections->[0]->username, 'overridden' );

