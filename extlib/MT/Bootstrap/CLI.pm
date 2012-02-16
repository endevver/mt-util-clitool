# MT::Bootstrap::CLI
#
# A subclass of MT::Bootstrap which allows for command-line MT::Apps. See
# README for further details.
#
# Author:   Jay Allen, Endevver LLC (http://endevver.com)
# Date:     March 1st, 2007
#
# Released under the Artistic License

package MT::Bootstrap::CLI;

use strict;
use FindBin qw($Bin);
use File::Spec;
use File::Basename qw(dirname);
use base qw( MT::Bootstrap );

sub import {
    my $pkg = shift;

    # MT::CLI tools should always have this set
    die("MT_HOME environment variable not set")
        unless $ENV{MT_HOME} and -d $ENV{MT_HOME};

    # Add the lib/extlib directories for the tool, if any
    my $envelope = dirname($Bin);
    foreach ( qw( lib extlib ) ) {
        my $lib = File::Spec->catdir( $envelope, $_ );
        unshift @INC, $lib if -d $lib;
    }

    # Setting GATEWAY_INTERFACE prevents MT::Bootstrap from assuming the
    # current app is running under FastCGI and is the only one of the
    # environment variables that are not used elsewhere in MT (It's only 
    # used in CGI.pm which of course, isn't used in a command-line app.).
    #
    # The other variables -- HTTP_HOST, SCRIPT_FILENAME and SCRIPT_URL --
    # are all used in MT and/or MT::App.
    $ENV{GATEWAY_INTERFACE} = 0;

    # Force DebugMode on if we detect a --debug flag and subsequent number
    if ( join(' ', @ARGV) =~ m/\-\-debug\s+(\d+)/ ) {
        my $debug_level = $1;
        require MT;
        printf "Temporarily bumping DebugMode from %d (%03b) to %d (%03b)\n",
             $MT::DebugMode,
             $MT::DebugMode, 
             local $MT::DebugMode |= $debug_level,
             $MT::DebugMode;

         die "That was unexpected";
         eval { 
             use Devel::TraceMethods;
             require MacLeod::Tool::BlogDelete;
             Devel::TraceMethods->callback(
                 MacLeod::Tool::BlogDelete->can('log_devel_tracemethods')
             )
         };
    }
    $pkg->SUPER::import(@_) or return;
}

1;

