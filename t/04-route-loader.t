use Modern::Perl;
use Test::More;
use Mojo::JSON qw(decode_json);
use Mojolicious;
use Test::Mojo;
use File::Spec;
use FindBin;

my $file = File::Spec->catfile(
    $FindBin::Bin, '..', 'Koha', 'Plugin', 'Com', 'Ecombranding',
    'EbookContent', 'openapi.json'
);
open my $fh, '<:raw', $file or die $!;
local $/;
my $paths = decode_json(<$fh>);
close $fh;

my $spec = {
    swagger  => '2.0',
    info     => { title => 'Koha plugin route compatibility test', version => '0.1.2' },
    basePath => '/api/v1/contrib/ebookcontent',
    schemes  => ['http'],
    paths    => $paths,
};

my $app = Mojolicious->new;
my $registered = eval {
    $app->plugin( OpenAPI => { spec => $spec, plugins => [] } );
    1;
};
ok( $registered, 'installed Mojolicious::Plugin::OpenAPI registers merged plugin routes' )
    or diag($@);

ok( !Mojolicious::Routes::Route->can('head'), 'installed route class has no explicit head method' );

my $routing_app = Mojolicious->new;
$routing_app->routes->get('/content')->to(
    cb => sub {
        my ($c) = @_;
        $c->res->headers->content_type('application/pdf');
        $c->res->headers->content_length(5);
        $c->render( data => 'PDF!!' );
    }
);
my $t = Test::Mojo->new($routing_app);
$t->head_ok('/content')->status_is(200)->header_is( 'Content-Type' => 'application/pdf' )->content_is('');

done_testing;
