package Koha::Plugin::Com::Ecombranding::EbookContent;

use Modern::Perl;
use base qw(Koha::Plugins::Base);

use C4::Context;
use Cwd qw(abs_path);
use Digest::SHA qw(sha256_hex);
use File::Spec;
use Mojo::JSON qw(decode_json encode_json);
use Koha::Biblios;
use Koha::UploadedFiles;
use Koha::Token;

use Koha::Plugin::Com::Ecombranding::EbookContent::Path qw(safe_real_path);

our $VERSION = '0.1.2';
our $metadata = {
    name            => 'Koha Controlled eBook Content API',
    author          => 'Ecombranding',
    description     => 'Private OAuth2-authenticated PDF delivery for Koha bibliographic eBook records.',
    date_authored   => '2026-07-12',
    date_updated    => '2026-07-13',
    minimum_version => '26.05.00.000',
    version         => $VERSION,
};

sub new {
    my ( $class, $args ) = @_;
    $args //= {};
    $args->{metadata} = $metadata;
    return $class->SUPER::new($args);
}

sub api_namespace { return 'ebookcontent' }

sub api_routes {
    my ($self) = @_;
    return decode_json( $self->mbf_read('openapi.json') );
}

sub mapping_table { return shift->get_qualified_table_name('mappings') }

sub install {
    my ($self) = @_;
    my $table = $self->mapping_table;
    my $dbh   = C4::Context->dbh;
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS `$table` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `biblionumber` INT UNSIGNED NOT NULL,
            `uploaded_file_id` INT NOT NULL,
            `active` TINYINT(1) NOT NULL DEFAULT 1,
            `original_filename_cache` TEXT NOT NULL,
            `file_size_cache` BIGINT UNSIGNED NOT NULL,
            `sha256_cache` CHAR(64) NOT NULL,
            `created_by` INT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `ebook_biblio_uq` (`biblionumber`),
            UNIQUE KEY `ebook_upload_uq` (`uploaded_file_id`),
            KEY `ebook_active_idx` (`active`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    });
    my %defaults = (
        api_enabled              => 1,
        allowed_upload_category => 'EBOOK_PDF',
        service_account_ids      => '[]',
        max_range_bytes          => 8388608,
    );
    my %missing = map { $_ => $defaults{$_} } grep { !defined $self->retrieve_data($_) } keys %defaults;
    $self->store_data(\%missing) if %missing;
    return 1;
}

sub upgrade {
    my ($self) = @_;
    # Version 0.1.2 has no schema change; retain the idempotent definition.
    return $self->install;
}

sub uninstall {
    my ($self) = @_;
    # Intentionally preserve mapping data and all Koha uploads.
    return 1;
}

sub settings {
    my ($self) = @_;
    my $ids = eval { decode_json( $self->retrieve_data('service_account_ids') // '[]' ) };
    $ids = [] unless ref($ids) eq 'ARRAY';
    return {
        api_enabled              => ( $self->retrieve_data('api_enabled') // 1 ) ? 1 : 0,
        allowed_upload_category => 'EBOOK_PDF',
        service_account_ids      => [ grep { defined($_) && /^\d+$/ && $_ > 0 } @$ids ],
        max_range_bytes          => 0 + ( $self->retrieve_data('max_range_bytes') // 8388608 ),
    };
}

sub save_settings {
    my ( $self, $params ) = @_;
    my %seen;
    my @ids = grep { !$seen{$_}++ } grep { /^\d+$/ && $_ > 0 } @{ $params->{service_account_ids} // [] };
    my $max = $params->{max_range_bytes};
    die 'Invalid maximum range size' unless defined($max) && $max =~ /^\d+$/ && $max <= 1073741824;
    $self->store_data({
        api_enabled              => $params->{api_enabled} ? 1 : 0,
        allowed_upload_category => 'EBOOK_PDF',
        service_account_ids      => encode_json(\@ids),
        max_range_bytes          => 0 + $max,
    });
    return 1;
}

sub service_account_allowed {
    my ( $self, $patron_id ) = @_;
    return 0 unless defined($patron_id) && $patron_id =~ /^\d+$/;
    my %allowed = map { $_ => 1 } @{ $self->settings->{service_account_ids} };
    return $allowed{$patron_id} ? 1 : 0;
}

sub _mapping {
    my ( $self, $biblionumber ) = @_;
    return unless defined($biblionumber) && $biblionumber =~ /^\d+$/ && $biblionumber > 0;
    my $table = $self->mapping_table;
    return C4::Context->dbh->selectrow_hashref(
        "SELECT id,biblionumber,uploaded_file_id,active,original_filename_cache,file_size_cache,sha256_cache,created_by,created_at,updated_at FROM `$table` WHERE biblionumber=?",
        undef, $biblionumber
    );
}

sub _sha256_file {
    my ( $self, $path ) = @_;
    open my $fh, '<:raw', $path or die 'UPLOAD_UNREADABLE';
    my $sha = Digest::SHA->new(256);
    my $buffer;
    while ( read( $fh, $buffer, 65536 ) ) { $sha->add($buffer) }
    close $fh or die 'UPLOAD_UNREADABLE';
    return $sha->hexdigest;
}

sub validate_upload {
    my ( $self, $biblionumber, $upload_id, $params ) = @_;
    $params //= {};
    die 'BIBLIO_NOT_FOUND' unless defined($biblionumber) && $biblionumber =~ /^\d+$/;
    die 'UPLOAD_NOT_FOUND' unless defined($upload_id) && $upload_id =~ /^\d+$/;
    my $biblio = Koha::Biblios->find($biblionumber) or die 'BIBLIO_NOT_FOUND';
    my $upload = Koha::UploadedFiles->find($upload_id) or die 'UPLOAD_NOT_FOUND';
    die 'UPLOAD_INVALID' unless $upload->permanent;
    die 'UPLOAD_INVALID' if $upload->public;
    die 'UPLOAD_INVALID' unless ( $upload->uploadcategorycode // '' ) eq 'EBOOK_PDF';
    die 'NOT_PDF' unless ( $upload->filename // '' ) =~ /\.pdf\z/i;
    my $path = safe_real_path( $upload->permanent_directory, $upload->full_path );
    die 'UPLOAD_UNREADABLE' unless -f $path && -r $path;
    my $size = -s $path;
    die 'UPLOAD_INVALID' unless defined($size) && $size > 0;
    open my $fh, '<:raw', $path or die 'UPLOAD_UNREADABLE';
    my $signature = '';
    my $read = read( $fh, $signature, 5 );
    close $fh;
    die 'NOT_PDF' unless defined($read) && $read == 5 && $signature eq '%PDF-';
    return {
        biblio => $biblio,
        upload => $upload,
        path   => $path,
        size   => $size,
        sha256 => $params->{compute_sha256} ? $self->_sha256_file($path) : undef,
    };
}

sub validated_mapping {
    my ( $self, $biblionumber ) = @_;
    my $mapping = $self->_mapping($biblionumber) or die 'MAPPING_NOT_FOUND';
    die 'MAPPING_INACTIVE' unless $mapping->{active};
    my $validated = $self->validate_upload( $biblionumber, $mapping->{uploaded_file_id} );
    $validated->{mapping} = $mapping;
    return $validated;
}

sub link_mapping {
    my ( $self, $biblionumber, $upload_id, $actor ) = @_;
    my $v = $self->validate_upload( $biblionumber, $upload_id, { compute_sha256 => 1 } );
    my $table = $self->mapping_table;
    my $dbh = C4::Context->dbh;
    my ($other) = $dbh->selectrow_array(
        "SELECT biblionumber FROM `$table` WHERE uploaded_file_id=? AND biblionumber<>?",
        undef, $upload_id, $biblionumber
    );
    die 'UPLOAD_ALREADY_MAPPED' if $other;
    $dbh->do(qq{
        INSERT INTO `$table`
          (biblionumber,uploaded_file_id,active,original_filename_cache,file_size_cache,sha256_cache,created_by)
        VALUES (?,?,?,?,?,?,?)
        ON DUPLICATE KEY UPDATE uploaded_file_id=VALUES(uploaded_file_id),active=1,
          original_filename_cache=VALUES(original_filename_cache),file_size_cache=VALUES(file_size_cache),
          sha256_cache=VALUES(sha256_cache),updated_at=CURRENT_TIMESTAMP
    }, undef, $biblionumber, $upload_id, 1, $v->{upload}->filename, $v->{size}, $v->{sha256}, $actor );
    return $v;
}

sub set_mapping_active {
    my ( $self, $biblionumber, $active ) = @_;
    if ($active) {
        my $mapping = $self->_mapping($biblionumber) or die 'MAPPING_NOT_FOUND';
        $self->validate_upload( $biblionumber, $mapping->{uploaded_file_id} );
    }
    my $table = $self->mapping_table;
    C4::Context->dbh->do( "UPDATE `$table` SET active=? WHERE biblionumber=?", undef, $active ? 1 : 0, $biblionumber );
    return 1;
}

sub list_mappings {
    my ($self) = @_;
    my $table = $self->mapping_table;
    return C4::Context->dbh->selectall_arrayref(
        "SELECT biblionumber,uploaded_file_id,active,original_filename_cache,file_size_cache,sha256_cache,updated_at FROM `$table` ORDER BY biblionumber",
        { Slice => {} }
    );
}

sub configure {
    my ($self) = @_;
    my $cgi = $self->{cgi};
    my $session_id = $cgi->cookie('CGISESSID') // '';
    my $tokenizer = Koha::Token->new;
    my $message;
    my $error;
    if ( ( $cgi->request_method // '' ) eq 'POST' ) {
        my $valid = $tokenizer->check_csrf({ session_id => $session_id, token => scalar $cgi->param('csrf_token') });
        if (!$valid) {
            $error = 'The form expired or failed CSRF validation.';
        } else {
            my $op = $cgi->param('op') // '';
            eval {
                if ( $op eq 'cud-link' ) {
                    my $actor = C4::Context->userenv->{number};
                    $self->link_mapping( scalar $cgi->param('biblionumber'), scalar $cgi->param('upload_id'), $actor );
                    $message = 'Mapping verified and saved.';
                } elsif ( $op eq 'cud-toggle' ) {
                    $self->set_mapping_active( scalar $cgi->param('biblionumber'), scalar $cgi->param('active') );
                    $message = 'Mapping status updated.';
                } elsif ( $op eq 'cud-settings' ) {
                    my @ids = split /[\s,]+/, scalar( $cgi->param('service_account_ids') // '' );
                    $self->save_settings({
                        api_enabled         => scalar $cgi->param('api_enabled'),
                        service_account_ids => \@ids,
                        max_range_bytes     => scalar $cgi->param('max_range_bytes'),
                    });
                    $message = 'API settings updated.';
                }
                1;
            } or $error = 'The requested change could not be completed safely.';
        }
    }
    my $template = $self->get_template({ file => 'configure.tt' });
    my $settings = $self->settings;
    $template->param(
        csrf_token         => $tokenizer->generate_csrf({ session_id => $session_id }),
        message            => $message,
        error              => $error,
        mappings           => $self->list_mappings,
        api_enabled        => $settings->{api_enabled},
        service_account_ids => join( ',', @{ $settings->{service_account_ids} } ),
        max_range_bytes    => $settings->{max_range_bytes},
    );
    $self->output_html( $template->output );
}

1;
