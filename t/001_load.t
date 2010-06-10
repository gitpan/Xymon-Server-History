# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 2;

BEGIN { use_ok( 'Xymon::Server::History' ); }

my $object = Xymon::Server::History->new ();
isa_ok ($object, 'Xymon::Server::History');


