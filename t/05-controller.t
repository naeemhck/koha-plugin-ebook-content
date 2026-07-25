use Modern::Perl;
use Test::More;
use Test::Mojo;
use Mojolicious;
use File::Spec;
use File::Temp qw(tempdir);
use FindBin;

use lib File::Spec->catdir( $FindBin::Bin, '..' );

BEGIN {
    package Koha::Plugin::Com::Ecombranding::EbookContent;
    sub new { die 'the controller test must inject its fake plugin' }
    $INC{'Koha/Plugin/Com/Ecombranding/EbookContent.pm'} = __FILE__;
}

require Koha::Plugin::Com::Ecombranding::EbookContent::Controller;

{
    package Local::Patron;
    sub new { bless { id => $_[1] }, $_[0] }
    sub borrowernumber { return shift->{id} }

    package Local::Upload;
    sub new { bless { filename => $_[1] }, $_[0] }
    sub filename { return shift->{filename} }

    package Local::Plugin;
    sub new { bless { path => $_[1], size => $_[2] }, $_[0] }
    sub settings { return { api_enabled => 1, max_range_bytes => 8_388_608 } }
    sub service_account_allowed { return defined $_[1] && $_[1] == 53 }
    sub validated_mapping {
        my ( $self, $id ) = @_;
        die 'BIBLIO_NOT_FOUND' if !defined($id) || $id eq '999';
        die 'MAPPING_NOT_FOUND' if $id eq '2';
        die 'MAPPING_INACTIVE' if $id eq '3';
        die 'UPLOAD_INVALID' if $id eq '4';
        return {
            upload => Local::Upload->new("unsafe\r\n/path.pdf"),
            path   => $self->{path},
            size   => $self->{size},
        };
    }
}

my $dir = tempdir( CLEANUP => 1 );
my $pdf = File::Spec->catfile( $dir, 'source.pdf' );
my $bytes = "%PDF-1.4\ncontroller compatibility test\n";
open my $out, '>:raw', $pdf or die $!;
print {$out} $bytes;
close $out or die $!;

my $plugin = Local::Plugin->new( $pdf, length($bytes) );
my $app = Mojolicious->new;
$app->hook( before_dispatch => sub {
    my ($c) = @_;
    my $id = $c->req->headers->header('X-Test-Patron');
    $c->stash( 'koha.user' => Local::Patron->new($id) ) if defined $id;
} );
$app->routes->get('/ebooks/:biblio_id/content')->to(
    cb => sub { Koha::Plugin::Com::Ecombranding::EbookContent::Controller::content( $_[0] ) }
);
my $t = Test::Mojo->new($app);

no warnings 'redefine';
local *Koha::Plugin::Com::Ecombranding::EbookContent::Controller::_plugin = sub { return $plugin };

$t->head_ok('/ebooks/1/content')->status_is(403)->content_is('');
$t->head_ok('/ebooks/1/content' => { 'X-Test-Patron' => 54 })->status_is(403)->content_is('');
$t->head_ok('/ebooks/999/content' => { 'X-Test-Patron' => 53 })->status_is(404)->content_is('');
$t->head_ok('/ebooks/2/content' => { 'X-Test-Patron' => 53 })->status_is(404)->content_is('');
$t->head_ok('/ebooks/3/content' => { 'X-Test-Patron' => 53 })->status_is(409)->content_is('');
$t->head_ok('/ebooks/4/content' => { 'X-Test-Patron' => 53 })->status_is(409)->content_is('');

{
    no warnings 'redefine';
    local *Mojo::Asset::File::new = sub { die 'HEAD_ATTACHED_FILE_ASSET' };
    $t->head_ok('/ebooks/1/content' => { 'X-Test-Patron' => 53 })
      ->status_is(200)
      ->header_is( 'Content-Type' => 'application/pdf' )
      ->header_is( 'Content-Length' => length($bytes) )
      ->header_is( 'Accept-Ranges' => 'bytes' )
      ->header_is( 'Content-Disposition' => 'inline; filename="unsafe_path.pdf"' )
      ->header_is( 'Cache-Control' => 'private, no-store' )
      ->header_is( 'Pragma' => 'no-cache' )
      ->header_is( 'X-Content-Type-Options' => 'nosniff' )
      ->header_is( 'Referrer-Policy' => 'no-referrer' )
      ->content_is('');
}

$t->head_ok('/ebooks/1/content' => { 'X-Test-Patron' => 53, Range => 'bytes=0-4' })
  ->status_is(206)
  ->header_is( 'Content-Range' => 'bytes 0-4/' . length($bytes) )
  ->header_is( 'Content-Length' => 5 )
  ->content_is('');

$t->get_ok('/ebooks/1/content' => { 'X-Test-Patron' => 53 })
  ->status_is(200)
  ->content_is($bytes);

$t->get_ok('/ebooks/1/content' => { 'X-Test-Patron' => 53, Range => 'bytes=0-4' })
  ->status_is(206)
  ->header_is( 'Content-Range' => 'bytes 0-4/' . length($bytes) )
  ->header_is( 'Content-Length' => 5 )
  ->content_is('%PDF-');

$t->get_ok('/ebooks/1/content' => { 'X-Test-Patron' => 53, Range => 'bytes=999999-' })
  ->status_is(416)
  ->header_is( 'Content-Range' => 'bytes */' . length($bytes) );

unlike( $t->tx->res->body, qr{(?:[A-Za-z]:[\\/]|/home/|/var/|file://|https?://)}i, 'error exposes no URL or internal path' );

opendir my $dh, $dir or die $!;
my @files = grep { $_ ne '.' && $_ ne '..' } readdir $dh;
closedir $dh;
is_deeply( \@files, ['source.pdf'], 'requests create no second persistent PDF copy' );

done_testing;
