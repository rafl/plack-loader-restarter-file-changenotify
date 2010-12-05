package Plack::Loader::Restarter::File::ChangeNotify::Backend::Forking;

use Moose;
use namespace::autoclean;

with 'Plack::Loader::Restarter::File::ChangeNotify::Backend';

has _child => (
    is  => 'rw',
    isa => 'Int',
);

sub fork_and_start {
    my ($self, $server) = @_;

    if (my $pid = fork) {
        $self->_child($pid);
    }
    else {
        $server->run($self->_builder->());
    }
}

sub kill_child {
    my ($self) = @_;

    return unless $self->_child;
    return unless kill 0, $self->_child;

    die "Cannot send INT signal to ", $self->_child, ": $!"
        unless kill 'INT', $self->_child;

    # If we don't wait for the child to exit, we could attempt to
    # start a new server before the old one has given up the port it
    # was listening on.
    wait;
}

1;
