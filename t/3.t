# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'
#########################
use strict;
use Test;
BEGIN { plan tests => 8 }
#########################
use FindBin;
use X12::Parser;

#setup
my ( $loop, $pos, $level );

my $sample_file = "$FindBin::RealBin/sample_835.txt";
my $sample_cf   = "$FindBin::RealBin/../cf/835_004010X091.cf";
my $p           = new X12::Parser;
$p->parse( file => "$sample_file", conf => "$sample_cf" );

#test
$loop = $p->get_next_loop;
ok( $loop, 'ISA' );

#test
$loop = $p->get_next_loop;
ok( $loop, 'GS' );

#test
( $pos, $loop ) = $p->get_next_pos_loop;
ok( $pos, 3 );

#test
( $pos, $level, $loop ) = $p->get_next_pos_level_loop;
ok( $level, 1 );

#test
# parse the file again
$p->parse( file => "$sample_file", conf => "$sample_cf" );
$loop = $p->get_next_loop;
ok( $loop, 'ISA' );

#test
$loop = $p->get_next_loop;
ok( $loop, 'GS' );

#test
( $pos, $loop ) = $p->get_next_pos_loop;
ok( $pos, 3 );

#test
( $pos, $level, $loop ) = $p->get_next_pos_level_loop;
ok( $level, 1 );
