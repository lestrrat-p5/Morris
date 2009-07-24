# $Id: Handle.pm 19334 2008-09-15 11:38:14Z daisuke $

package Morris::Plugin::Channel::Log::Handle;
use Moose::Role;
use Moose::Util::TypeConstraints;

with 'Morris::Plugin::Channel::Log';

subtype 'Morris::Types::DateTime::Format'
    => as 'Object'
    => where {
        $_->can('parse_datetime') &&
        $_->can('format_datetime')
    }
;

has 'handle' => (
    is      => 'rw',
    isa     => 'IO::Handle',
    lazy    => 1,
    builder => 'build_handle'
);

has 'datetime_formatter' => (
    is      => 'rw',
    does    => 'Morris::Types::DateTime::Format',
    lazy    => 1,
    builder => 'build_datetime_formatter'
);

requires 'build_handle';

no Moose::Role;
no Moose::Util::TypeConstraints;

sub log_message {
    my ($self, $args) = @_;

    my $fh = $self->handle;
    print $fh ($self->format_message($args));
}

sub format_message {
    my ($self, $args) = @_;

    my $dt_fmt = $self->datetime_formatter;
    my $message = $args->{message};

    return sprintf(
        "%s|%s|%s: %s\n",
        $dt_fmt->format_datetime(DateTime->now(time_zone => 'local')),
        $message->channel,
        $message->from->nickname,
        $message->message
    );
}

sub build_datetime_formatter {
    require DateTime::Format::Strptime;
    return DateTime::Format::Strptime->new(pattern => "%Y-%m-%d %T");
}

1;