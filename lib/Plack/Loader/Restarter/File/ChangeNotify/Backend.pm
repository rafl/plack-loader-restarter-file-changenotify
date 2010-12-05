package Plack::Loader::Restarter::File::ChangeNotify::Backend;

use Moose::Role;
use Plack::Loader;
use File::ChangeNotify;
use namespace::autoclean;

# reuse, but no inheritance
__PACKAGE__->meta->add_method($_ => Plack::Loader->can($_))
    for qw(auto load guess);

has directories => (
    traits  => [qw(Array)],
    isa     => 'ArrayRef',
    default => sub { [] },
    handles => {
        directories => 'elements',
        watch       => 'push',
    },
);

has _watcher => (
    is      => 'rw',
    isa     => 'File::ChangeNotify::Watcher',
    lazy    => 1,
    builder => '_build__watcher',
);

has filter => (
    is      => 'rw',
    isa     => 'RegexpRef',
    builder => '_build_filter',
);

has _changenotify_args => (
    is     => 'ro',
    isa    => 'HashRef',
);

has _builder => (
    is  => 'rw',
    isa => 'CodeRef',
);

requires qw(fork_and_start kill_child);

around BUILDARGS => sub {
    my $orig = shift;
    my ($class) = @_;
    my $args = $orig->(@_);

    my %init_args = map {
        ($_->init_arg => 1)
    } $class->meta->get_all_attributes;

    $args->{_changenotify_args} = {
        map { ($_ => $args->{$_}) }
            grep { !$init_args{$_} } keys %{ $args }
    };

    delete @{ $args }{keys %{ $args->{_changenotify_args} }};

    $args;
};

sub _build_filter {
    return qr/(?:\/|^)(?![.#_]).+(?:\.yml$|\.yaml$|\.conf|\.pm)$/;
}

sub _build__watcher {
    my ($self) = @_;

    return File::ChangeNotify->instantiate_watcher(
        directories => [$self->directories],
        filter      => $self->filter,
        %{ $self->_changenotify_args || {} },
    );
}

sub preload_app {
    my ($self, $builder) = @_;
    $self->_builder($builder);
}

sub run {
    my ($self, $server, $builder) = @_;
    $self->run_and_watch($server);
}

sub run_and_watch {
    my ($self, $server) = @_;

    $self->fork_and_start($server);
    return unless $self->_child;

    $self->_restart_on_changes($server);
}

sub _restart_on_changes {
    my ($self, $server) = @_;

    # We use this loop in order to avoid having _handle_events() call back
    # into this method. We used to do that, and the end result was that stack
    # traces became longer and longer with every restart. Using this loop, the
    # portion of the stack trace that covers this code does not grow.
    while (1) {
        my @events = $self->_watcher->wait_for_events();
        $self->_handle_events($server, @events);
    }
}

sub _handle_events {
    my ($self, $server, @events) = @_;

    my @files;
    # Filter out any events which are the creation / deletion of directories
    # so that creating an empty directory won't cause a restart
    for my $event (@events) {
        my $path = $event->path();
        my $type = $event->type();
        if (   ( $type ne 'delete' && -f $path )
            || ( $type eq 'delete' && $path =~ $self->_filter ) )
        {
            push @files, { path => $path, type => $type };
        }
    }

    if (@files) {
        print STDERR "\n";
        print STDERR "Saw changes to the following files:\n";

        for my $f (@files) {
            my $path = $f->{path};
            my $type = $f->{type};
            print STDERR " - $path ($type)\n";
        }

        print STDERR "\n";
        print STDERR "Attempting to restart the server\n\n";

        $self->kill_child;

        $self->fork_and_start($server);
    }
}

sub DEMOLISH { }

after DEMOLISH => sub {
    my ($self) = @_;

    $self->kill_child;
};

1;
