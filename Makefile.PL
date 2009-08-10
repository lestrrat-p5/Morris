use inc::Module::Install;

name('Morris');
all_from('lib/Morris.pm');

requires 'Config::Any';
requires 'Config::General';
requires 'Digest::MD5';
requires 'DBI';
requires 'DateTime';
requires 'DBI';
requires 'HTML::Parse';
requires 'Image::Size';
requires 'LWP::UserAgent';
requires 'Moose';
requires 'MooseX::AttributeHelpers';
requires 'MooseX::ConfigFromFile';
requires 'MooseX::Singleton';
requires 'MooseX::Types::Path::Class';
requires 'MooseX::Types::URI';
requires 'POE::Component::IRC';
requires 'POE::Component::IKC::ClientLite';
requires 'SQL::Abstract::Limit';
requires 'Template';
requires 'Template::Stash::ForceUTF8';
requires 'XML::LibXML';
requires 'namespace::clean';

recommends 'Text::MeCab';
recommends 'Web::Scraper';
recommends 'WWW::Mechanize';

test_requires 'Test::UseAllModules';

auto_include_deps;
WriteAll;
