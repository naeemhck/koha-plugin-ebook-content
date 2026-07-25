use Modern::Perl;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/..";
use Koha::Plugin::Com::Ecombranding::EbookContent::Range qw(parse_range);

sub dies_like (&$) {
    my ( $code, $pattern ) = @_;
    my $error = eval { $code->(); 1 } ? '' : $@;
    like( $error, $pattern );
}

is_deeply( parse_range( undef, 100, 0 ), { status=>200,start=>0,end=>99,length=>100 }, 'full response' );
is_deeply( parse_range( 'bytes=0-9', 100, 0 ), { status=>206,start=>0,end=>9,length=>10 }, 'bounded range' );
is_deeply( parse_range( 'bytes=10-', 100, 0 ), { status=>206,start=>10,end=>99,length=>90 }, 'open-ended range' );
dies_like { parse_range( 'bytes=-10', 100, 0 ) } qr/RANGE_INVALID/;
dies_like { parse_range( 'bytes=0-1,3-4', 100, 0 ) } qr/RANGE_INVALID/;
dies_like { parse_range( 'bytes=10-9', 100, 0 ) } qr/RANGE_UNSATISFIABLE/;
dies_like { parse_range( 'bytes=100-', 100, 0 ) } qr/RANGE_UNSATISFIABLE/;
dies_like { parse_range( 'bytes=0-100', 100, 0 ) } qr/RANGE_UNSATISFIABLE/;
dies_like { parse_range( 'items=0-1', 100, 0 ) } qr/RANGE_INVALID/;
dies_like { parse_range( 'bytes=0-10', 100, 10 ) } qr/RANGE_TOO_LARGE/;
done_testing;
