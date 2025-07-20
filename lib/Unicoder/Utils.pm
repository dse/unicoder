package Unicoder::Utils;
use warnings;
use strict;
use Unicode::UCD qw(charblocks charinfo charprop);

use base "Exporter";
our @EXPORT = qw(parse_number u output_char);
our @EXPORT_OK = qw();
our %EXPORT_TAGS = (all => \@EXPORT_OK);

our $charblocks = charblocks();
our @block_names = sort {
    $charblocks->{$a}[0][0] - $charblocks->{$b}[0][0]
} keys %$charblocks;

sub u {
    my ($codepoint, $pad) = @_;
    if ($codepoint < 0) {
        return sprintf("%-8d", $codepoint) if $pad;
        return $codepoint;
    }
    my $u = sprintf("U+%04X", $codepoint);
    return sprintf("%-8s", $u) if $pad;
    return $u;
}

sub find_charblock {
    my ($query) = @_;
    if (exists $charblocks->{$query}) {
        return $charblocks->{$query};
    }
    my $result;
    if (defined ($result = parse_number($query))) {
        return find_charblock_by_codepoint($result);
    }
    if (defined ($result = parse_block_name($query))) {
        return $charblocks->{$result};
    }
}

sub find_charblock_by_codepoint {
    my ($codepoint) = @_;
    my @block_names = grep {
        $charblocks->{$_}[0][0] <= $codepoint && $codepoint <= $charblocks->{$_}[0][1]
    } @block_names;
    return $charblocks->{$block_names[0]} if scalar @block_names == 1;
    return;
}

sub parse_number {
    my ($str) = @_;
    return hex($1) if $str =~ /^(?:u\+|0x)([[:xdigit:]]+)$/i;
    return oct($1) if $str =~ /^0(\d+)$/;
    return 0 + $1  if $str =~ /^\d+$/;
    return;
}

sub parse_block_name {
    my ($block_name) = @_;
    my $normalized_block_name = normalize($block_name);
    my @block_names = grep { $normalized_block_name eq normalize($_) } @block_names;
    return $block_names[0] if scalar @block_names == 1;
    return;
}

sub normalize {
    my ($str) = @_;
    $str = lc $str;
    $str =~ s/[^A-Za-z0-9]+//g;
    return $str;
}

sub output_char {
    my ($codepoint, %options) = @_;
    my $str = "";
    $str .= u($codepoint, 1);

    if ($options{char}) {
        $str .= sprintf("  %s", display_char($codepoint));
    }

    my $property = $options{property};
    if (defined $property) {
        $str .= sprintf("  %-24s", charprop($codepoint, $property));
    }

    $str .= "  " . get_charname($codepoint) . "\n";
    return $str;
}

sub get_charname {
    my ($codepoint) = @_;
    my $charinfo = charinfo($codepoint);
    return if !defined $charinfo;
    return $charinfo->{name};
}

our %NOPRINT;
our %COMBINE;

BEGIN {
    %NOPRINT = (
        Line_Separator => 1,
        Paragraph_Separator => 1,
        Space_Separator => 1,
        Control => 1,
        Format => 1,
        Surrogate => 1,
        Private_User => 1,
    );
    %COMBINE = (
        Nonspacing_Mark => 1,
        Spacing_Mark => 1,
        Enclosing_Mark => 1,
    );
}

sub display_char {
    my ($codepoint) = @_;
    my $chr = chr($codepoint);
    my $gc = charprop($codepoint, "gc");
    if ($NOPRINT{$gc}) {
        return " ";
    }
    if ($COMBINE{$gc}) {
        return "X" . $chr;
    }
    return $chr;
}

1;
