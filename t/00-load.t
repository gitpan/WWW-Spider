#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'WWW::Spider' );
}

diag( "Testing WWW::Spider $WWW::Spider::VERSION, Perl $], $^X" );
