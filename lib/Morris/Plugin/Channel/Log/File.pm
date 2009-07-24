# $Id: File.pm 19333 2008-09-15 11:35:36Z daisuke $

package Morris::Plugin::Channel::Log::File;
use Moose;
use MooseX::Types::Path::Class qw(Dir File);
use File::Spec;

with 'Morris::Plugin::Channel::Log::Handle';

has 'directory' => (
    is       => 'rw',
    isa      => Dir,
    required => 1,
    coerce   => 1,
    builder  => 'build_dir',
    lazy     => 1
);

has 'file' => (
    is       => 'rw',
    isa      => File,
    required => 1,
    coerce   => 1,
    builder  => 'build_file',
    lazy     => 1
);

__PACKAGE__->meta->make_immutable;

no Moose;

sub build_dir {
    return Path::Class::Dir->new(File::Spec->tmpdir);
}

sub build_file {
    my $self = shift;
    my $file = $self->directory->file( 
        sprintf( '%s.log', $self->channel ) );
    return $file;
}

sub build_handle {
    my $self = shift;
    my $fh   =  $self->file->open('a');
    $fh->autoflush(1);
    return $fh;
}

1;