package Koha::Plugin::Com::Ecombranding::EbookContent::Range;

use Modern::Perl;
use Exporter qw(import);
our @EXPORT_OK = qw(parse_range);

sub parse_range {
    my ( $header, $size, $maximum ) = @_;
    die 'RANGE_INVALID' unless defined($size) && $size =~ /^\d+$/ && $size > 0;
    return { status => 200, start => 0, end => $size - 1, length => $size } unless defined($header) && length($header);
    die 'RANGE_INVALID' if $header =~ /,/;
    die 'RANGE_INVALID' unless $header =~ /\Abytes=(\d+)-(\d*)\z/;
    my ( $start, $end_text ) = ( 0 + $1, $2 );
    die 'RANGE_UNSATISFIABLE' if $start >= $size;
    my $end = length($end_text) ? 0 + $end_text : $size - 1;
    die 'RANGE_UNSATISFIABLE' if $end < $start || $end >= $size;
    my $length = $end - $start + 1;
    die 'RANGE_TOO_LARGE' if $maximum && $length > $maximum;
    return { status => 206, start => $start, end => $end, length => $length };
}

1;
