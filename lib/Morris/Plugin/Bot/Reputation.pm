# $Id$

package Morris::Plugin::Bot::Reputation;
use Moose;

with 'Morris::Plugin';

__PACKAGE__->meta->make_immutable;

no Moose;

sub handle_message {
    my ($self, $args) = @_;

    my $schema = $self->global_resource('schema.master');
    my $rs     = $schema->resultset('Reputation');
    while ($message =~ /\b([^+-]+)(\+\+|--)\b/g) {
        my ($nickname, $type) = ($1, $2);

        $self->log_reputation({ nickname => $1, type => $2 });
    }
}

sub log_reputation {
}

1;