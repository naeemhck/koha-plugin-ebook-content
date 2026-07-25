use Modern::Perl;
use Test::More;
use Mojo::JSON qw(decode_json);
use File::Spec;
use FindBin;

my $file = File::Spec->catfile( $FindBin::Bin, '..', 'Koha', 'Plugin', 'Com', 'Ecombranding', 'EbookContent', 'openapi.json' );
open my $fh, '<:raw', $file or die $!; local $/; my $spec = decode_json(<$fh>); close $fh;
ok( $spec->{'/ebooks/{biblio_id}/metadata'}->{get}->{'x-koha-authorization'}, 'metadata declares authorization' );
ok( $spec->{'/ebooks/{biblio_id}/content'}->{get}->{'x-koha-authorization'}, 'content GET declares authorization' );
ok( !exists $spec->{'/ebooks/{biblio_id}/content'}->{head}, 'content has no incompatible explicit HEAD operation' );
is_deeply(
    [ sort keys %{ $spec->{'/ebooks/{biblio_id}/content'} } ],
    ['get'],
    'content declares only the supported explicit GET operation'
);
is( $spec->{'/ebooks/{biblio_id}/content'}->{get}->{'x-mojo-to'}, 'Com::Ecombranding::EbookContent::Controller#content', 'controller convention' );
is( $spec->{'/ebooks/{biblio_id}/metadata'}->{get}->{'x-mojo-to'}, 'Com::Ecombranding::EbookContent::Controller#metadata', 'metadata controller convention' );
done_testing;
