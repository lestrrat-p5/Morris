use inc::Module::Install;

name 'Morris';
all_from 'lib/Morris.pm';
requires 'AnyEvent';
requires 'AnyEvent::DBI';
requires 'AnyEvent::Handle';
requires 'AnyEvent::HTTP';
requires 'AnyEvent::IRC';
requires 'Config::Any';
requires 'Encode';
requires 'EV'; # want to make it plaggable?
requires 'File::Temp';
requires 'HTML::TreeBuilder';
requires 'Image::Size';
requires 'Moose' => '0.92';
requires 'MooseX::Getopt';
requires 'MooseX::SimpleConfig' => 0.04;
requires 'SQL::Abstract::Limit'; # want to remove
requires 'Text::MeCab';
requires 'URI';
requires 'XML::LibxML' => '1.61';
requires 'namespace::clean';

WriteAll;
