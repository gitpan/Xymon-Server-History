package Xymon::Server::History;

use Xymon::Server;
use File::Find;
use Time::Local;
use Data::Dumper;
use Time::Business;

use strict;

BEGIN {
    use Exporter ();
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $month $week $weekday $bustime);
    $VERSION     = '0.05';
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
	
	my $bustime = Time::Business->new({
		WORKDAYS=>$param->{WORKDAYS},
		STARTTIME=>$param->{STARTTIME},
		ENDTIME=>$param->{ENDTIME},
	});
	
	$self->{datadir} = $xymon->{BBVAR};	
	$month={Jan=>0,Feb=>1,Mar=>2,Apr=>3,May=>4,Jun=>5,Jul=>6,Aug=>7,Sep=>8,Oct=>9,Nov=>10,Dec=>11};
	$week = {Sun=>0,Mon=>1,Tue=>2,Wed=>3,Thu=>4,Fri=>5,Sat=>6};
	$weekday = {0=>'Sun',1=>'Mon',2=>'Tue',3=>'Wed',4=>'Thu',5=>'Fri',6=>'Sat'};
	$self->allEvents($param);
		
    return $self;
}

sub allEvents {
	
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


	my @dirdepth = split /\//, "$self->{datadir}/histlogs";
	my $depth = @dirdepth;
	
	find( sub { 
		
		my $t = $File::Find::name;
		
		
			
						
			my @words = split /\//, $t;
			my $length = @words;
			
			if($length > $depth + 2) {
					
				my $server = $words[$depth];
				my $test = $words[$depth+1];
				my $filename = $words[$depth+2];
									
				if($servers->{$server} == 1 || @servers == 0 ) {
					if($tests->{$test} == 1 || @tests == 0 ) {
											
						$self->{history}->{$server}->{$test}->{$filename}->{filename} 
								= $self->{datadir} . "/histlogs/" . $server . "/" . $test . "/" . $filename;
						
						
						
						my @dt = split(/_/,$filename);
						my @time = split(/:/,$dt[3]);
	
						
						$self->{history}->{$server}->{$test}->{$filename}->{day} = $week->{$dt[0]};
						
						$self->{history}->{$server}->{$test}->{$filename}->{time} = 
								(timelocal($time[2],$time[1],$time[0],$dt[2],$month->{$dt[1]},$dt[4]-1900));
			
					}
				}
			}	
		
			 
	},$self->{datadir} . "/histlogs/" ); 
	print "Loaded " . scalar (localtime) . "\n";
	return $self->{history};
}


sub outagelist {
	

	my $self = shift;
	my $param = shift;
	
				
	
	$self->{outages}={};	
		
	
	my $hist_hashref;
	if( defined $self->{history}) {
		$hist_hashref = $self->{history};
	} else {
		$hist_hashref = $self->allEvents($param);
	}
	
				
	foreach my $hostname (keys %{$hist_hashref}) {
		foreach my $test (keys %{$hist_hashref->{$hostname}}) {
			my $ref = $hist_hashref->{$hostname}->{$test};
			
			my $startcolor;
			my $endcolor;
			my $evtref={};
			foreach my $file (sort{$ref->{$a}->{time} <=> $ref->{$b}->{time}}keys %{$ref}){
				
				open( my $evtfile, "<", $ref->{$file}->{filename});
				my $eventline = <$evtfile>;
				chomp $eventline;
				
				my $color = (split / /,$eventline)[0];
				if ($color eq "red" && $startcolor ne "red") {
					$startcolor="red";
					
					$evtref=$ref->{$file};
					
						
				} elsif ($color ne "red" && $startcolor eq "red") {
					
					$endcolor=$color;
					
					my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($evtref->{time});
					my $start24 = $hour * 100 + $min; 
					
					($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($ref->{$file}->{time});
					my $end24 = $hour * 100 + $min;
					
					$self->{outages}->{$evtref->{time}} = {
						server => $hostname,
						test => $test,
						startday => $evtref->{day},
						start24hour => $start24,
						endday => $ref->{$file}->{day},
						endtime => $ref->{$file}->{time},
						end24hour => $end24,
						duration => $ref->{$file}->{time} - $evtref->{time},
						business => $bustime->calctime($evtref->{time},$ref->{$file}->{time}),
						filename => $ref->{$file}->{filename}
					};
					if(defined $param->{STARTTIME}) {
						#print "$evtref->{time},$ref->{$file}->{time}\n";
						#$self->{outages}->{$evtref->{time}}->{business_duration} = $hours->between($evtref->{time},$ref->{$file}->{time});
					}
					
						
					$startcolor="";
					$endcolor="";
				}
				
				
				close($evtfile);	
					
			}
		}
	} 
	print scalar (localtime) . " : Finished\n";
	return $self->{outages};
	
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
					conn => {
						"file1"=>{
							filename => "fullfilename"
							time => "time in unix format"
						}
						"file2" => {
							filename => "fullfilename"
							time => "time in unix format"
						}
				  },

		server2 => {
					uptime => "file1"=>{
							filename => "fullfilename"
							time => "time in unix format"
						}
						"file2" => {
							filename => "fullfilename"
							time => "time in unix format"
						}
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

=head2 outagelist({...}) 
	
	outagelist({
		SERVERS => ["servername1","servername2"],
		TESTS => ["conn","uptime"]
	})

Returns a list of outages from red to non-red in the following format

	{
		starttime => {
			server => "servername"
			test => "testname"
			eventend => "time"
		}
	}

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

