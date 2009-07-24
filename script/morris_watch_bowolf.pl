#!/usr/local/bin/perl
use lib "/service/morris/Morris/lib";
use Morris::CLI::WatchBowolf;

Morris::CLI::WatchBowolf->new_with_options()->run() ;
