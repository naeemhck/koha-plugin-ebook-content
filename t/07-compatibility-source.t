use Modern::Perl;
use Test::More;
use Digest::SHA qw(sha256_hex);
use File::Spec;
use FindBin;

my $root = File::Spec->catdir( $FindBin::Bin, '..' );

sub source {
    my (@parts) = @_;
    my $file = File::Spec->catfile( $root, @parts );
    open my $fh, '<:raw', $file or die $!;
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

my @plugin = qw(Koha Plugin Com Ecombranding);
my %unchanged = (
    'EbookContent/Controller.pm' => 'c8091eda91bffac83d20b4cda954384ef4833a9d7f40c6b0cc785e3c323d6acc',
    'EbookContent/Path.pm'       => '29841157f76287f47d4f4235e95e420493926f2d9a74f9fade865db505e03e0a',
    'EbookContent/Range.pm'      => '1573f3e5165442ad805f6b9255085858f40fbd937f9e5d75eb9a044ec5d5af79',
    'EbookContent/configure.tt'  => '71d612f3579c79061493a772cf6908623430b02044d1af6a40281b51d97d62f8',
);

for my $relative ( sort keys %unchanged ) {
    my @parts = split m{/}, $relative;
    is( sha256_hex( source( @plugin, @parts ) ), $unchanged{$relative}, "$relative is byte-identical to 0.1.1" );
}

my $main = source( @plugin, 'EbookContent.pm' );
unlike( $main, qr/\b(?:ALTER|DROP)\s+TABLE\b/i, '0.1.2 adds no schema migration' );
like( $main, qr/sub upgrade\s*\{.*?return \$self->install;.*?\}/s, 'upgrade retains the existing idempotent lifecycle path' );

done_testing;
