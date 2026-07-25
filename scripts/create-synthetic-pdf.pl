#!/usr/bin/perl
use strict;
use warnings;

my $output = shift or die "Usage: $0 OUTPUT.pdf\n";
die "Refusing non-PDF output\n" unless $output =~ /\.pdf\z/i;
my @objects = (
  '<< /Type /Catalog /Pages 2 0 R >>',
  '<< /Type /Pages /Kids [3 0 R 4 0 R 5 0 R] /Count 3 >>',
  '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 6 0 R >> >> /Contents 7 0 R >>',
  '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 6 0 R >> >> /Contents 8 0 R >>',
  '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 6 0 R >> >> /Contents 9 0 R >>',
  '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
);
for my $page (1..3) {
    my $text = "BT /F1 18 Tf 72 720 Td (Koha controlled eBook plugin proof - Page $page) Tj ET";
    push @objects, "<< /Length " . length($text) . " >>\nstream\n$text\nendstream";
}
my $pdf = "%PDF-1.4\n";
my @offsets = (0);
for my $i (0..$#objects) { push @offsets, length($pdf); $pdf .= ($i+1)." 0 obj\n$objects[$i]\nendobj\n" }
my $xref = length($pdf);
$pdf .= "xref\n0 " . (@objects+1) . "\n0000000000 65535 f \n";
$pdf .= sprintf("%010d 00000 n \n", $_) for @offsets[1..$#offsets];
$pdf .= "trailer\n<< /Size " . (@objects+1) . " /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n";
open my $fh, '>:raw', $output or die "$output: $!\n"; print {$fh} $pdf; close $fh or die "$output: $!\n";
print "$output\n";
