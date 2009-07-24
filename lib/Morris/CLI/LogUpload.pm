package Morris::CLI::LogUpload;
use utf8;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::AttributeHelpers;
use MooseX::Types::URI;
use Config::Any;
use DateTime;
use DateTime::Format::Strptime;
use DBI;
use Encode qw(encode_utf8);
use File::Temp;
use Template;
use Template::Stash::ForceUTF8;
use WWW::Mechanize;

with 'MooseX::Getopt';
with 'MooseX::ConfigFromFile';

has '+configfile' => (
    default => '/etc/morris.conf'
);

has dbh => (
    is => 'ro',
    lazy_build => 1
);

subtype 'Morris::CLI::ValueList'
    => as 'ArrayRef'
;
coerce 'Morris::CLI::ValueList'
    => from 'Str'
    => via { [ $_ ] }
;
has connect_info => (
    is => 'rw',
    isa => 'Morris::CLI::ValueList',
    required => 1,
    coerce => 1,
    auto_deref => 1,
);

has channels => (
    metaclass => 'Collection::Array',
    is => 'ro',
    isa => 'Morris::CLI::ValueList',
    coerce => 1,
    required => 1,
    provides => {
        elements => 'all_channels'
    }
);

has base_url => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has target => (
    is => 'rw',
    isa => 'Str',
    trigger => sub {
        my $date = DateTime::Format::Strptime->new(
            pattern => '%Y-%m-%d',
            time_zone => 'Asia/Tokyo'
        )->parse_datetime($_[1] );
        $date->set(hour => 6);
        $_[0]->date( $date )
    }
);

has date => (
    is => 'rw',
    isa => 'DateTime',
    default => sub {
        DateTime->now(time_zone => 'Asia/Tokyo')
            ->truncate(to => 'day')
            ->set(hour => 6)
    }
);

has basic_auth_username => (
    is => 'ro',
    isa => 'Str'
);

has basic_auth_password => (
    is => 'ro',
    isa => 'Str'
);

has wiki_username => (
    is => 'ro',
    isa => 'Str'
);

has wiki_password => (
    is => 'ro',
    isa => 'Str'
);

has format => (
    is => 'ro',
    isa => enum([ qw(textile markdown) ]),
    required => 1,
    default => 'textile',
);

my %templates = (
    textile => <<EOM,
h1. [% channel %] - [% date.strftime('%Y-%m-%d') %]

h2. メッセージ

[% FOREACH message IN messages %]
|[[% message.created_on.strftime('%H:%M') %]]|*[% message.nickname %]*|[% message.message %]|[% END %]

h2. 統計情報

|メッセージ数|[% messages.size %]|
EOM
    markdown => <<EOM,
# [% channel %] - [% date.strftime('%Y-%m-%d') %]

## メッセージ

| 時間 | 発言者 | 発言 |
---|
[% FOREACH message IN messages -%]
|[[% message.created_on.strftime('%H:%M') %]]|*[% message.nickname %]*|[% message.message %]|
[% END %]
EOM
);



sub get_config_from_file
{
    my ($class, $file) = @_;

    my $cfg = Config::Any->load_files({
        files => [ $file ],
        use_ext => 1,
        driver_args => {
            General => {
                -LowerCaseNames => 1
            }
        }
    });

    return (scalar @$cfg > 0 && $cfg->[0]->{$file}->{logupload})
        or die "Could not load $file";
}

sub run {
    my $self  = shift;

    foreach my $channel ($self->all_channels) {
        $self->handle_channel($channel);
    }
}

sub make_url {
    my $self = shift;
    my $uri  = URI->new($self->base_url);
    $uri->path($uri->path ? join('/', $uri->path, @_) : @_);
    $uri;
}

sub _build_dbh {
    my $self = shift;
    $self->{connect_info}->[3] = { RaiseError => 1, AutoCommit => 1 };
    DBI->connect($self->connect_info);
}

sub handle_channel {
    my ($self, $channel) = @_;

    my $start = $self->date->clone;

    my $dbh = $self->dbh;

    my $sth = $dbh->prepare("SELECT * FROM log WHERE channel = ? AND created_on >= ? AND created_on <= ?");
    $sth->execute($channel, $start->epoch, $start->clone->add(days => 1)->epoch);

    my @messages;
    while (my $h = $sth->fetchrow_hashref) {
        push @messages, $h;
        $h->{message} =~ s/\|/\\|/g;
        $h->{message} =~ s{((?:(?:https?):)(?://(?:[^\s/?#]*))(?:[^\s?#]*)(?:\?(?:[^\s#]*))?(?:#(?:.*))?)}{"$1":$1}g;
        $h->{created_on} = DateTime->from_epoch(epoch => $h->{created_on}, time_zone => 'Asia/Tokyo');
    }
    $sth->finish;
    $dbh->disconnect;

    return if !@messages;

    my $tt = Template->new(
        STASH => Template::Stash::ForceUTF8->new
    );
    my %vars = (
        channel  => $channel,
        date     => $start,
        messages => \@messages,
    );
    my $output = '';
    my $template = $templates{ $self->format };
    $tt->process(\$template, \%vars, \$output) or
        die $tt->error;
    $output = encode_utf8($output);
warn $output;
    my $ua = WWW::Mechanize->new();
    if ($self->basic_auth_username && $self->basic_auth_password ) {
        $ua->credentials( $self->basic_auth_username, $self->basic_auth_password );
    }

    $ua->get($self->make_url(".login"));
    my $res = $ua->submit_form(
        form_number => 1,
        fields => {
            login => $self->wiki_username,
            pass  => $self->wiki_password,
        }
    );

    $ua->get($self->make_url( "/Log/" . $start->strftime('%Y-%m-%d') . ".edit" ));

    $ua->submit_form(
        form_number => 2,
        fields => {
            body => $output,
        },
        button => "submit",
    );
}

__PACKAGE__->meta->make_immutable;

