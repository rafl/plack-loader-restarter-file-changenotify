use strict;
use warnings;

package Plack::Loader::Restarter::File::ChangeNotify;

use Class::MOP;
use parent 'Plack::Loader';

sub pick_subclass {
    my ($class) = @_;

    my $env = "PLACK_LOADER_RESTARTER_FILE_CHANGENOTIFY_BACKEND";
    my $subclass =
        defined $ENV{$env}
            ? $ENV{$env}
            :  $^O eq 'MSWin32'
            ? 'Win32'
            : 'Forking';

    $subclass = __PACKAGE__ . '::Backend::' . $subclass;

    Class::MOP::load_class($subclass);

    return $subclass;
}

# I know! but sadly this is the API Plack requires us to implement
sub new {
    my $class = shift;
    my $subclass = $class->pick_subclass;
    return $subclass->new(@_);
}

1;
