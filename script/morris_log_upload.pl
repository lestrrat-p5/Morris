#!/usr/local/bin/perl
use strict;
use Morris::CLI::LogUpload;

main() unless caller();

sub main {
    Morris::CLI::LogUpload->new_with_options->run();
}