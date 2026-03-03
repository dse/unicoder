package Unicoder::Print;
use warnings;
use strict;
use Unicode::UCD qw(charinfo charprop);
use POSIX qw(ceil);

use File::Basename qw(dirname);
use lib dirname(__FILE__) . "/..";
use Unicoder::AdobeGlyphNames qw(get_glyph_name_by_codepoint);

use base "Exporter";
our @EXPORT = ();
our @EXPORT_OK = qw(char_line_as_string
                    print_char_as_string
                    u);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

our $octal_columns = ceil(length(sprintf("%#o", 0x10ffff)) / 2) * 2;

sub char_line_as_string {
    my ($codepoint, @args) = @_;
    my %args = (scalar @args == 1 && ref $args[0] eq "HASH") ?
      %{$args[0]} : @args;
    my $charinfo = charinfo($codepoint);
    my $charname   = defined $charinfo ? $charinfo->{name} : undef;
    my $charname10 = defined $charinfo ? $charinfo->{unicode10} : undef;
    foreach ($charname, $charname10) {
        $_ = undef if defined $_ && !/\S/;
    }
    my $str = "";
    $str .= u($codepoint, 1);

    if ($args{decimal}) {
        $str .= sprintf("  %8d", $codepoint);
    }
    if ($args{octal}) {
        my $len = length(sprintf("%#o", 0x10ffff));
        $len = ceil($len / 2) * 2;
        my $o = sprintf("%#o", $codepoint);
        $str .= sprintf("  %*s", $octal_columns, $o);
    }
    if ($args{print_gc}) {
        my $category = defined $charinfo ? $charinfo->{category} : undef;
        $str .= sprintf("  %-2s", $category // "Cn");
    }
    if ($args{print_category}) {
        my $category = charprop($codepoint, "General Category");
        $str .= sprintf("  %-24s", $category // "(none)");
    }
    if ($args{print_char}) {
        $str .= sprintf("  %-2s", print_char_as_string($codepoint));
    }
    if ($args{adobe}) {
        $str .= sprintf("  %-20s", get_glyph_name_by_codepoint($codepoint));
    }

    if (defined $charname && defined $charname10) {
        $str .= sprintf("  %s (%s)", $charname, $charname10);
    } elsif (defined $charname) {
        $str .= sprintf("  %s", $charname);
    } elsif (defined $charname10) {
        $str .= sprintf("  (%s)", $charname10);
    } else {
        $str .= "  (no name)"
    }
    return $str;
}

my %NON_PRINTING = (
    "Control" => 1,             # e.g., U+0007 BELL
    "Line_Separator" => 1,      # U+2028 LINE SEPARATOR
    "Paragraph_Separator" => 1, # U+2029 PARAGRAPH SEPARATOR
    "Surrogate" => 1,           # e.g., U+D800
    "Space_Separator" => 1,     # e.g., U+202F NARROW NO-BREAK SPACE
    "Format" => 1,              # e.g., U+00AD SOFT HYPHEN
    "Private_Use" => 1,         # e.g., U+102345
    "Unassigned" => 1,          # e.g., U+34567

    "Cs" => 1,                  # Surrogate
    "Cf" => 1,                  # Format
    "Co" => 1,                  # Private Use
    "Cc" => 1,                  # Control
    "Cn" => 1,                  # Unassigned, or Reserved
    "Zs" => 1,                  # Space Separator
    "Zl" => 1,                  # Line Separator
    "Zp" => 1,                  # Paragraph Separator

    # "Other_Symbol" => 1,        # e.g., U+FFFD
);

sub print_char_as_string {
    my ($codepoint) = @_;
    if ($codepoint < 32 || $codepoint >= 127 && $codepoint <= 159) {
        return "?";
    }
    if ($codepoint < 0 || $codepoint >= 0x10ffff) {
        return "";
    }
    my $charinfo = charinfo($codepoint);
    my $gc = defined $charinfo ? $charinfo->{category} : "Cn";
    if ($NON_PRINTING{$gc}) {
        return "";
    }
    return chr($codepoint);
}

sub u {
    my ($codepoint, $columns) = @_;
    my $u;
    if ($codepoint < 0) {
        $u = sprintf("(%d)", $codepoint);
    } else {
        $u = sprintf("U+%04X", $codepoint);
    }
    if (defined $columns) {
        if ($codepoint < 0) {
            $u = sprintf("%8s", $u);
        } else {
            $u = sprintf("%-8s", $u);
        }
    }
    return $u;
}

1;
