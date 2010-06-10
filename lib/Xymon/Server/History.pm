package Xymon::Server::History;

use Xymon::Server;
use File::Find;

use strict;

BEGIN {
    use Exporter ();
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    $VERSION     = '0.01';
    @ISA         = qw(Exporter);
    #Give a hoot don't pollute, do not export more than needed by default
    @EXPORT      = qw();
    @EXPORT_OK   = qw();
    %EXPORT_TAGS = ();
}


sub new
{
    my ($class, $param) = @_;
    my $self = bless ({}, ref ($class) || $class);

	my $xymon = Xymon::Server->new({HOME=>$param->{HOME}});
	
	$self->{datadir} = $xymon->{BBVAR};	

	
    return $self;
}

sub load_history {
	
	my $self = shift;
	my $param = shift;
	
	my @servers = @{$param->{SERVERS}|| []};
	my @tests = @{$param->{TESTS}|| []};		
	
	my $count = 0;
	
	
	
	#
	# setup hash of servers for faster find comparison
	#
	my $servers = {};
	if(@servers > 0) {
		foreach my $server (@servers) {
			$servers->{$server} = 1;
		}
	}

	#
	# setup hash of tests for faster find comparison
	#
	my $tests = {};
	if(@tests > 0) {
		foreach my $test (@tests) {
			$tests->{$test} = 1;
		}
	}



	find( sub { 
		
		my $t = $File::Find::name;
		$t =~ s/$self->{datadir}\/histlogs\///;
		my @words = split /\//, $t;
		if(@words>2) {
			if($servers->{$words[0]} == 1 || @servers == 0 ) {
				if($tests->{$words[1]} == 1 || @tests == 0 ) {
					push @{$self->{history}->{$words[0]}->{$words[1]}}, $words[2];
				}
			}
		}	
			 
	},$self->{datadir} . "/histlogs/" ); 

}


=head1 NAME

Xymon::Server::History - Return a hash of Xymon events history

=head1 SYNOPSIS

  use Xymon::Server::History;
  
  my $history = Xymon::Server::History->new({HOME=>'/home/hobbit'})


=head1 DESCRIPTION

Various methods for returning differents views of the event data stored
in $HOBBITHOME/data/histlogs/

=head1 METHODS

=head2 new({...})

Instantiates the object.

You must pass it the HOME dir for hobbit. (One level below server).

	new({HOME=>'/home/hobbit'})
	
=head2 allEvents({....})

Returns a hash of events with following structure:

	{
		server1 => {
					conn => ["filename1","filename2","filename3"],
					test2 => ["filename1","filename2","filename3"],
				  },

		server2 => {
					uptime => ["filename1","filename2"],
					conn => ["filename1","filename2","filename3"],
				  }
	}

allEvents() will return events for all servers and tests.
This may be filter by passing an array of servers, 
and an array of tests in order to filter the results eg:

	allEvents({
		SERVERS => ["servername1","servername2"],
		TESTS => ["conn","uptime"]
	})

The filename of the event is in the format:	Fri_Dec_14_16:56:14_2007



=head1 AUTHOR

    David Peters
    CPAN ID: DAVIDP
    davidp@electronf.com
    http://www.electronf.com

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

perl(1).

=cut

#################### main pod documentation end ###################


1;
# The preceding line will help the module return a true value

