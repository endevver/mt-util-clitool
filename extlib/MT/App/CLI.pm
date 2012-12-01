package MT::App::CLI;

# See README.txt in this package for more details

use 5.010_001;
use strict;
use warnings;
use mro 'c3';
use Data::Dumper;
use Carp qw(longmess);
use Getopt::Long qw( :config auto_version auto_help );
use Pod::Usage;
use base 'MT::App';
# use Log::Log4perl qw( :resurrect );
###l4p use MT::Log::Log4perl qw(l4mtdump);
###l4p our $logger = MT::Log::Log4perl->new();

use version 0.77; our $VERSION = qv('v3.2.0');

$| = 1;

use constant CONFIG => 'mt-config.cgi';

sub option_spec {
    return ( 'debug|d:i', 'help|man!', 'usage|h!', 'verbose|v+' );
}

sub init {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    $app->next::method(@_) or return;
    $app;
}

sub init_request {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    $app->init_options(@_) or return;
    require CGI;
    $app->{query} = CGI->new({ %{$app->options} });
    ###l4p $logger->debug('CGI query object initialized');    
    $app->next::method( CGIObject => $app->{query} );
    MT->set_instance($app);
    $app->{query};
}

sub options { $_[0]->{options} }

sub init_options {
    my $app         = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    my %opt = ();
    my $opts_good = GetOptions(
        \%opt, $app->option_spec()
    );
    unless ( $opts_good ) {
        print STDERR join( '', @{ $app->{trace} } ) if $app->{trace};
        $app->show_usage({ -exitval => 2, -verbose => 0 });
    }
    $app->show_usage()      if $opt{usage};
    $app->show_docs()       if $opt{help};
    $app->{options} = \%opt;
    $app->init_debug_mode() if $opt{debug};
    ###l4p $logger->debug('Completing '.__PACKAGE__.'::init_options');
    1;
}

sub run {
    my $app = shift;
    local $@;
    my $out = eval { $app->next::method(@_) };
    Carp::confess("'$@'") if defined $@;
    Carp::confess('No output from run mode '.$app->mode) unless defined $out;
    return "'$out'";
}


sub init_plugins {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    $app->next::method(@_);
}

sub init_addons {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    $app->next::method(@_);
}

sub init_debug_mode {
    my $app        = shift;
    my $opt        = $app->options;
    my $dbmode     = $app->config('DebugMode');
    my $pkg_dbmode = $MT::DebugMode;

    # print Dumper({
    #     opt_debug      => $opt->{debug}, 
    #     dbmode         => $dbmode, 
    #     pkg_dbmode     => $pkg_dbmode,
    #     dbmode_bin     => sprintf( "%03b", $dbmode), 
    #     pkg_dbmode_bin => sprintf( "%03b", $pkg_dbmode),
    #     appconfigdebugmode => $app->config->DebugMode,
    # });

    $dbmode |= $opt->{debug} if $opt->{debug};
    # print 'dbmode '.__LINE__.' '.$dbmode."\n";
    
    $app->config('DebugMode', $dbmode );
    # print '$app->config(DebugMode): '.__LINE__.' '.$app->config('DebugMode')."\n";

    require MT;
    $MT::DebugMode = $dbmode;
    # print "\$MT::DebugMode ".__LINE__.": $MT::DebugMode\n";
    # print '$app->config(DebugMode): '.__LINE__.' '.$app->config('DebugMode')."\n";
}

sub pre_run {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    MT->set_instance($app);
    $app->next::method(@_);
    my $opt = $app->options();
    my $blog_param = defined $opt->{blog}       ? $opt->{blog}
                   : defined $opt->{blog_id}    ? $opt->{blog_id}
                                                : undef;
    if ( $blog_param ) { # 0 is not valid!
        my $blog = $app->load_by_name_or_id( 'blog', $blog_param );
        $app->blog( $blog ) if $blog;
    }
}

sub mode_default {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    $app->show_usage();
}

sub post_run {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    $app->print(('OUTPUT-----'x10), "\n");
    $app->next::method(@_);
    if ($app->{trace} &&
        (!defined $app->{warning_trace} || $app->{warning_trace})) {
        my $trace = '';
        foreach (@{$app->{trace}}) {
            $trace .= "MT DEBUG: $_\n";
            # $trace .= $logger->indent("MT DEBUG: $_\n");
        }
        $app->print_trace($trace);
    }
    # $app->{query}->save(\*STDOUT);
}

sub print_trace {
    my ($app, $trace) = @_;
    my $del = 'TRACE------'x10;
    $app->print("\n",join("\n", $del, $trace, $del), "\n");
}

sub show_error {
    my $app = shift;
    my $error = $_[0]->{error};
    my $stack = ($error and $app->param('verbose')) ? longmess() : '';
    
    $app->print("FATAL> $error (".(caller(1))[3].')'. $stack);
    return;
}

sub show_usage { 
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    pod2usage({
        # Two defaults for usage, can be overriden
         -exitval => 1,
         -verbose => 0,
        # Arguments supplied by caller
         (
             @_ != 1              ? @_                    #  > 1 or 0
           : ref $_[0] eq 'HASH'  ? %{ $_[0] }            # hashref
           : ref $_[0] eq 'ARRAY' ? @{ $_[0] }            # arrayref
           : ! ref $_[0]          ? ( -message => shift ) # msg only
           : ()                                           # no args
         )
    });
}

sub show_options { 
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    pod2usage(@_ ? @_ : { -exitval => 1, -verbose => 1 });
}

sub show_docs {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    pod2usage(@_ ? @_ : { -exitval => 1, -verbose => 2 });
}

sub send_http_header { }

sub takedown {
    my $app = shift;
    $app->next::method(@_);
    $app->print("\n");
    return;
}

# mt_dir() works to locate the MT directory so that you can
# call your script from another location if you wish as such:
#
#     MT_HOME=/path/to/mt ~/mt-example.pl ARG1 ARG2
#
sub mt_dir {
    use Cwd qw( getcwd );
    use File::Basename qw(dirname);
    my @search_dirs = (getcwd, $ENV{MT_HOME});
    my $mt_dir;
    BASE: foreach my $base (@search_dirs) {
        next unless $base and -d $base;
        DIR: foreach my $dir ($base, dirname($base), dirname(dirname($base))) {
            if (-e File::Spec->catfile($dir, CONFIG)) {
                $mt_dir = $dir;
                last BASE;
            }
        }
    }    
    $ENV{MT_HOME} = $mt_dir if $mt_dir;
}

sub load_by_name_or_id {
    require MT::CLI::Util;
    MT::CLI::Util::load_by_name_or_id(@_);
}

sub confirm_action {
    require MT::CLI::Util;
    MT::CLI::Util::confirm_action(@_);
}


1;
__END__


=head1 MT::App:CLI

sample - Using GetOpt::Long and Pod::Usage

=head1 SYNOPSIS

sample [options] [file ...]

 Options:
   -help            brief help message
   -man             full documentation

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut

