package Unicoder::Search;
use warnings;
use strict;
use Unicode::UCD qw(charinfo charblocks);
use JSON::XS;
use List::Util qw(min max);

our $CACHE_DIR = "$ENV{HOME}/.cache/unicoder";
our $DB_FILE = "${CACHE_DIR}/unicoder.json";
our $JSON = JSON::XS->new();
our $MIN_KEYWORD_LENGTH = 3;

our $charblocks = charblocks();
our @block_names = sort { $charblocks->{$a}->[0]->[0] <=> $charblocks->{$b}->[0]->[0] }
  keys %$charblocks;

our %DB = ();

our %NO_INDEX_BLOCK = (
    "CJK Unified Ideographs Extension A" => 1, # U+3400   naming scheme not useful for keyword searches
    "CJK Unified Ideographs"             => 1, # U+4E00   naming scheme not useful for keyword searches
    "High Surrogates"                    => 1, # U+D800   no useful search results
    "High Private Use Surrogates"        => 1, # U+DB80   no useful search results
    "Low Surrogates"                     => 1, # U+DC00   no useful search results
    "Private Use Area"                   => 1, # U+E000   no useful search results
    "Tangut"                             => 1, # U+17000  naming scheme not useful for keyword searches
    "Tangut Components"                  => 1, # U+18800  naming scheme not useful for keyword searches
    "CJK Unified Ideographs Extension B" => 1, # U+20000  naming scheme not useful for keyword searches
    "CJK Unified Ideographs Extension C" => 1, # U+2A700  naming scheme not useful for keyword searches
    "CJK Unified Ideographs Extension D" => 1, # U+2B740  naming scheme not useful for keyword searches
    "CJK Unified Ideographs Extension E" => 1, # U+2B820  naming scheme not useful for keyword searches
    "CJK Unified Ideographs Extension F" => 1, # U+2CEB0  naming scheme not useful for keyword searches
    "CJK Unified Ideographs Extension G" => 1, # U+30000  naming scheme not useful for keyword searches
    "Supplementary Private Use Area-A"   => 1, # U+F0000  no useful search results
    "Supplementary Private Use Area-B"   => 1, # U+100000 no useful search results
);

sub create_db {
    %DB = ();
    my $index = sub {
        my ($codepoint, $name_arrayref, $charname_idx) = @_;
        return if !defined $name_arrayref;
        return if ref $name_arrayref ne 'ARRAY';
        return if !scalar @$name_arrayref;
        $base_weight //= 1;
        my @name = @$name_arrayref;
        my $word_count = scalar @name;
        foreach my $word_idx (0 .. $#name) {
            my $word = lc($name[$word_idx]);
            my $word_len = length($word);
            foreach my $substr_len (min($MIN_KEYWORD_LENGTH, $word_len) .. $word_len) {
                foreach my $substr_idx (0 .. ($word_len - $substr_len)) {
                    my $substr = substr($word, $substr_idx, $substr_len);
                    my $weight_charname_idx = 0.8 ** $charname_idx;
                    my $weight_substr_idx = 0.95 ** $substr_idx;
                    my $weight_substr_len = $substr_len / $word_len;
                    my $weight_word_len   = 1.05 ** ($word_len - $MIN_KEYWORD_LENGTH);
                    my $weight_word_idx   = 0.95 ** $word_idx;
                    my $weight_word_count = 1.05 ** ($word_count - 1);
                    my $weight =
                      $weight_charname_idx *
                      $weight_substr_idx *
                      $weight_substr_len *
                      $weight_word_len *
                      $weight_word_idx *
                      $weight_word_count;
                    push(@{$DB{$substr}}, [$weight, $codepoint, $word_len, $substr_len, $substr_idx, $word_count, $word_idx]);
                }
            }
        }
    };
    my $saved;
    if (-t 2) {
        set_stderr_autoflush(1);
    }
    foreach my $block_name (@block_names) {
        next if $NO_INDEX_BLOCK{$block_name};
        my @blocks = @{$charblocks->{$block_name}};
        foreach my $block (@blocks) {
            my ($start, $end, $name) = @$block;
            if (-t 2) {
                printf STDERR ("\r\e[KIndexing %s (U+%04X .. U+%04X) ...", $start, $end, $name);
            }
            foreach my $codepoint ($start .. $end) {
                my $charinfo = charinfo($codepoint);
                next if (!defined $charinfo);
                my $unicode_name = $charinfo->{name};
                my $unicode_10_name = $charinfo->{unicode10};
                my @unicode_name = name_split($unicode_name);
                my @unicode_10_name = name_split($unicode_10_name);
                &$index($codepoint, \@unicode_name, 0);
                &$index($codepoint, \@unicode_10_name, defined $unicode_name ? 1 : 0);
            }
        }
    }
    if (-t 2) {
        printf STDERR ("\r\e[K");
        set_stderr_autoflush($saved);
    }
}

sub set_stderr_autoflush {
    my ($flag) = @_;
    my $sel = select(STDERR);
    my $saved = $|;
    $| = $flag;
    select($sel);
    return $saved;
}

sub load_db {
    my $fh;
    open($fh, '<', $DB_FILE) or return;
    local $/ = undef;
    my $json_text = <$fh>;
    close($fh);
    %DB = %{ $JSON->decode($json_text) };
}

sub save_db {
    my $fh;
    open($fh, '>', $DB_FILE) or return;
    print $fh $JSON->encode(\%DB);
    close $fh;
}

sub name_split {
    my ($name) = @_;
    return if !defined $name || $name !~ /\S/;
    return grep { $_ ne '' } split(/[^A-Za-z0-9]+/, $name);
}

1;
