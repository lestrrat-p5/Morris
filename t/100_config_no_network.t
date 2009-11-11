use strict;
use lib "lib";
use Test::More (tests => 1);
use App::Morris;

local @ARGV = qw(--configfile t/100_config_no_network.conf);
my $app = App::Morris->new_with_options();

eval {
    my $morris = Morris->new_from_config( $app->config );
};
like($@, qr/No network specified for connection 'test'/);

