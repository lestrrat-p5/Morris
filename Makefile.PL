use inc::Module::Install;

name('Morris');
all_from('lib/Morris.pm');

requires 'Config::Any';
requires 'Config::General';
requires 'DBI';
requires 'DateTime';
e
requires 'DBI';
requires 'Moose';
requires 'MooseX::ConfigFromFile';
requires 'MooseX::Singleton';
requires 'MooseX::Types::Path::Class';
requires 'POE::Component::IRC';

test_requires 'Test::UseAllModules';

auto_include_deps;
WriteAll;

use Config::Any;
use DBI;
use Data::Dumper;
use DateTime;
use File::Spec;
use HTML::Parse;
use Image::Size;
use LWP::UserAgent;
use Moose::Role;
use Moose::Util::TypeConstraints;
use Moose;
use MooseX::AttributeHelpers;
use MooseX::Types::Path::Class qw(Dir File);
use Morris::Client::Address;
use Morris::Connection;
use Morris::Engine;
use Morris::Message;
use Morris;
use POE qw(
use POE qw(Component::IRC);
use POE::Component::IKC::ClientLite;
use POE;
use SQL::Abstract::Limit;
use URI;
use XML::LibXML;
