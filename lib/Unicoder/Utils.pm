package Unicoder::Utils;
use warnings;
use strict;
use Unicode::UCD qw(charinfo charblocks);

use base "Exporter";
our @EXPORT = qw();
our @EXPORT_OK = qw(split_words
                    set_stderr_autoflush
                    set_autoflush
                    get_charnames
                    print_char
                    parse_codepoint
                    u);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

# my $autoflush = set_stderr_autoflush();
# ...
# set_stderr_autoflush($autoflush);
sub set_stderr_autoflush {
    my ($flag) = @_;
    $flag //= 1;
    my $saved_handle = select(STDERR);
    my $saved_autoflush = $|;
    $| = $flag;
    select($saved_handle);
    return $saved_autoflush;
}

sub set_autoflush {
    my ($fh, $flag) = @_;
    $flag //= 1;
    my $saved_handle = select($fh);
    my $saved_autoflush = $|;
    $| = $flag;
    select($saved_handle);
    return $saved_autoflush;
}

sub split_words {
    my ($name) = @_;
    return if !defined $name || $name !~ /[0-9a-z]/;
    $name = lc $name;
    return grep { /\S/ } split(/[^0-9a-z]+/, $name);
}

sub get_charnames {
    my ($codepoint, $array, $control) = @_;
    my $charinfo = charinfo($codepoint);
    return if !defined $charinfo;
    my $charname    = $charinfo->{name};
    my $charname_10 = $charinfo->{unicode10};
    if ($control) {
        $charname = undef if defined $charname && $charname eq "<control>";
    }
    if (!$array) {
        return grep { defined $_ && /\S/ } ($charname, $charname_10);
    }
    $charname    = lc $charname    if defined $charname;
    $charname_10 = lc $charname_10 if defined $charname_10;
    my @charname    = split_words($charname);
    my @charname_10 = split_words($charname_10);
    my @names;
    push(@names, \@charname) if scalar @charname;
    push(@names, \@charname_10) if scalar @charname_10;
    return @names;
}

sub u {
    my ($codepoint) = @_;
    return sprintf("U+%04X", $codepoint);
}

sub print_char {
    my ($codepoint) = @_;
    my $charinfo = charinfo($codepoint);
    return " " if !defined $charinfo;
    my $category = $charinfo->{category}; # Gc => Lu, Ll, ...
    return " " if $category eq "Cc";      # Control
    return " " if $category eq "Cf";      # Format
    return " " if $category eq "Co";      # Private Use
    return " " if $category eq "Cs";      # Surrogate
    return " " if $category eq "Zl";      # Line Separator
    return " " if $category eq "Zp";      # Paragraph Separator
    return " " if $category eq "Zs";      # Space Separator
    return " " . chr($codepoint) if $category eq "Mn"; # Nonspacing Mark (for combining marks)
    return chr($codepoint);
}

sub parse_codepoint {
    my ($str) = @_;
    return if !defined $str;
    if (length($str) == 1) {
        return ord($str);
    }
    if ($str =~ /^(?:u\+?|0?x)([0-9A-Fa-f]+)$/i) {
        return hex($1);
    }
    if ($str =~ /^(?:0|[1-9][0-9]*)$/) {
        return 0 + $&;
    }
    return;
}


1;
