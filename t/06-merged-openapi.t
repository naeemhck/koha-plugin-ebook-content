use Modern::Perl;
use Test::More;
use JSON::Validator;
use Mojo::JSON qw(decode_json);
use File::Spec;
use FindBin;

my $core = '/usr/share/koha/api/v1/swagger/swagger.yaml';
ok( -f $core, 'installed Koha core OpenAPI document is available' );

my $plugin_file = File::Spec->catfile(
    $FindBin::Bin, '..', 'Koha', 'Plugin', 'Com', 'Ecombranding',
    'EbookContent', 'openapi.json'
);
open my $fh, '<:raw', $plugin_file or die $!;
local $/;
my $plugin_paths = decode_json(<$fh>);
close $fh;

my $validator = JSON::Validator->new;
$validator->schema($core);
my $schema = $validator->schema;

for my $path ( keys %{$plugin_paths} ) {
    my $merged_path = '/contrib/ebookcontent' . $path;
    ok( !exists $schema->data->{paths}->{$merged_path}, "$merged_path does not collide with a core route" );
    $schema->data->{paths}->{$merged_path} = $plugin_paths->{$path};
}

ok( exists $schema->data->{paths}->{'/oauth/token'}, 'merged document retains Koha OAuth token route' );
my $errors = $schema->errors;
is( scalar @{$errors}, 0, 'full Koha and plugin merged OpenAPI document validates' )
    or diag join "\n", map { "$_" } @{$errors};

done_testing;
