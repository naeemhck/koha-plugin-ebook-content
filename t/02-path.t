use Modern::Perl;
use Test::More;
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/..";
use Koha::Plugin::Com::Ecombranding::EbookContent::Path qw(safe_real_path safe_filename);

my $root = tempdir( CLEANUP => 1 );
my $inside = File::Spec->catfile( $root, 'inside.pdf' );
open my $fh, '>:raw', $inside or die $!; print {$fh} "%PDF-test"; close $fh;
is( safe_real_path( $root, $inside ), File::Spec->rel2abs($inside), 'file inside root accepted' );

my $outside_root = tempdir( CLEANUP => 1 );
my $outside = File::Spec->catfile( $outside_root, 'outside.pdf' );
open $fh, '>:raw', $outside or die $!; print {$fh} "%PDF-test"; close $fh;
eval { safe_real_path( $root, $outside ) };
like( $@, qr/UNSAFE_PATH/, 'outside file rejected' );

SKIP: {
    my $link = File::Spec->catfile( $root, 'escape.pdf' );
    skip 'symlink creation unavailable', 1 unless eval { symlink $outside, $link };
    eval { safe_real_path( $root, $link ) };
    like( $@, qr/UNSAFE_PATH/, 'symlink escape rejected' );
}

is( safe_filename("bad\r\n\"/name.pdf"), 'bad_name.pdf', 'header filename sanitized' );
is( safe_filename('../secret'), '_secret.pdf', 'leading dots and extension handled' );
done_testing;
