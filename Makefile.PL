sub author_tests  { }
sub use_test_base { warn "You need to install Test::Base to run make test from git clone" }
sub readme_from   { }
sub install_share { warn "You need to install Module::Install::Share to install from git clone" }
sub auto_set_repository { }

use inc::Module::Install;

name 'Morris';
all_from 'lib/Morris.pm';
requires 'AnyEvent';
requires 'AnyEvent::DBI';
requires 'AnyEvent::Handle';
requires 'AnyEvent::IRC';
requires 'Config::Any';
requires 'Encode';
requires 'File::Temp';
requires 'Moose' => '0.92';
requires 'MooseX::Getopt';
requires 'MooseX::SimpleConfig' => 0.04;
requires 'namespace::clean';

# optional dependencies
feature 'Morris::Plugin::QOTD requirements',
    'Text::MeCab';

feature 'Morris::Plugin::PeekURL requirements',
    'AnyEvent::HTTP',
    'HTML::TreeBuilder',
    'Image::Size',
    'URI';

feature 'Morris::Plugin::YSearch requirements',
    'AnyEvent::HTTP',
    'URI',
    'XML::LibXML' => '1.61';

install_script 'script/morris';
auto_install;
auto_include;
auto_set_repository;
WriteAll;
