package Plack::Loader::Restarter::File::ChangeNotify::Backend::Win32;

use Moose;
use namespace::autoclean;

with 'Plack::Loader::Restarter::File::ChangeNotify::Backend';

has _child => (
    is  => 'rw',
    isa => 'Proc::Background',
);

sub fork_and_start {
    my ($self, $server) = @_;

    # This is totally hack-tastic, and is probably much slower, but it
    # does seem to work.
    my @command = ( $^X, map("-I$_", @INC), $0, grep { ! /^\-r/ } @{ $self->argv } );

    my $child = Proc::Background->new(@command);

    $self->_child($child);
}

sub kill_child {
    my ($self) = @_;

    return unless $self->_child;

    $self->_child->die;
}

1;
