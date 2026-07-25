package Koha::Plugin::Com::Ecombranding::EbookContent::Path;

use Modern::Perl;
use Exporter qw(import);
use Cwd qw(abs_path);
use File::Spec;

our @EXPORT_OK = qw(safe_real_path safe_filename);

sub safe_real_path {
    my ( $root, $candidate ) = @_;
    die 'UNSAFE_PATH' unless defined($root) && defined($candidate);
    die 'UNSAFE_PATH' if $root =~ /\0/ || $candidate =~ /\0/;
    my $real_root = abs_path($root)      or die 'UNSAFE_PATH';
    my $real_file = abs_path($candidate) or die 'UPLOAD_MISSING';
    my $relative  = File::Spec->abs2rel( $real_file, $real_root );
    die 'UNSAFE_PATH' if File::Spec->file_name_is_absolute($relative);
    my @parts = File::Spec->splitdir($relative);
    die 'UNSAFE_PATH' if !@parts || grep { $_ eq File::Spec->updir } @parts;
    return $real_file;
}

sub safe_filename {
    my ($name) = @_;
    $name //= 'ebook.pdf';
    $name =~ s/[\r\n\\\/";\x00-\x1f\x7f]+/_/g;
    $name =~ s/[^A-Za-z0-9._ -]+/_/g;
    $name =~ s/^\.+//;
    $name = 'ebook.pdf' if $name eq '';
    $name .= '.pdf' unless $name =~ /\.pdf\z/i;
    return substr( $name, 0, 150 );
}

1;
