package Koha::Plugin::Com::Ecombranding::EbookContent::Controller;

use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Asset::File;
use Mojo::JSON qw(true false);

use Koha::Plugin::Com::Ecombranding::EbookContent;
use Koha::Plugin::Com::Ecombranding::EbookContent::Path qw(safe_filename);
use Koha::Plugin::Com::Ecombranding::EbookContent::Range qw(parse_range);

sub _plugin { return Koha::Plugin::Com::Ecombranding::EbookContent->new }

sub _authorized {
    my ( $c, $plugin ) = @_;
    return 0 unless $plugin->settings->{api_enabled};
    my $patron = $c->stash('koha.user');
    return 0 unless $patron;
    return $plugin->service_account_allowed( $patron->borrowernumber );
}

sub _safe_error {
    my ( $c, $error ) = @_;
    return $c->render( status => 404, json => { error => 'Biblio or eBook mapping not found' } )
        if $error =~ /BIBLIO_NOT_FOUND|MAPPING_NOT_FOUND/;
    return $c->render( status => 415, json => { error => 'Mapped content is not a valid PDF' } )
        if $error =~ /NOT_PDF/;
    return $c->render( status => 409, json => { error => 'Mapped upload is inactive or invalid' } )
        if $error =~ /MAPPING_INACTIVE|UPLOAD_|UNSAFE_PATH/;
    return $c->render( status => 500, json => { error => 'Internal server error' } );
}

sub metadata {
    my ($c) = @_;
    my $plugin = _plugin();
    return $c->render( status => 403, json => { error => 'Service account is not authorized' } )
        unless _authorized( $c, $plugin );
    my $v = eval { $plugin->validated_mapping( $c->param('biblio_id') ) };
    return _safe_error( $c, $@ ) unless $v;
    return $c->render( status => 200, json => {
        biblio_id => 0 + $v->{mapping}->{biblionumber},
        title     => $v->{biblio}->title,
        file      => {
            upload_id        => 0 + $v->{upload}->id,
            original_filename => $v->{upload}->filename,
            mime_type        => 'application/pdf',
            file_size_bytes  => 0 + $v->{size},
            sha256           => $v->{mapping}->{sha256_cache},
            category         => 'EBOOK_PDF',
            permanent        => true,
            public           => false,
            active           => true,
        },
    });
}

sub content {
    my ($c) = @_;
    my $plugin = _plugin();
    return $c->render( status => 403, json => { error => 'Service account is not authorized' } )
        unless _authorized( $c, $plugin );
    my $v = eval { $plugin->validated_mapping( $c->param('biblio_id') ) };
    return _safe_error( $c, $@ ) unless $v;

    my $settings = $plugin->settings;
    my $range = eval { parse_range( $c->req->headers->range, $v->{size}, $settings->{max_range_bytes} ) };
    if (!$range) {
        $c->res->headers->content_range( 'bytes */' . $v->{size} );
        $c->res->headers->accept_ranges('bytes');
        return $c->render( status => 416, json => { error => 'Requested range is not satisfiable' } );
    }

    my $filename = safe_filename( $v->{upload}->filename );
    my $headers = $c->res->headers;
    $headers->content_type('application/pdf');
    $headers->content_disposition( qq{inline; filename="$filename"} );
    $headers->accept_ranges('bytes');
    $headers->cache_control('private, no-store');
    $headers->header( 'Pragma' => 'no-cache' );
    $headers->header( 'X-Content-Type-Options' => 'nosniff' );
    $headers->header( 'Referrer-Policy' => 'no-referrer' );
    $headers->content_length( $range->{length} );
    $headers->content_range( "bytes $range->{start}-$range->{end}/$v->{size}" ) if $range->{status} == 206;

    return $c->rendered( $range->{status} ) if uc( $c->req->method ) eq 'HEAD';
    my $asset = Mojo::Asset::File->new( path => $v->{path} );
    $asset->start_range( $range->{start} )->end_range( $range->{end} );
    $c->res->content->asset($asset);
    return $c->rendered( $range->{status} );
}

1;
