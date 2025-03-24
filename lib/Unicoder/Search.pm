package Unicoder::Search;
use warnings;
use strict;
use List::Util qw(min uniq max);
use Unicode::UCD qw(charinfo charblocks);
use JSON::XS;
use File::Path qw(make_path);
use File::Basename qw(dirname);

use lib dirname(__FILE__) . "/..";
use Unicoder::Utils qw(get_charnames split_words set_stderr_autoflush);

use base "Exporter";
our @EXPORT = qw();
our @EXPORT_OK = qw(unicoder_create_db
                    unicoder_save_db
                    unicoder_load_db
                    unicoder_search_db);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

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
our $MIN_INDEX_LENGTH = 3;
our $JSON_FILENAME = "$ENV{HOME}/.local/share/unicoder/index.json";
our $JSON = JSON::XS->new();

our $DB = {};

sub unicoder_create_db {
    $DB = {};
    my $add_charname = sub {
        my ($codepoint, $which_charname, @charname) = @_;
        my $word_count = scalar @charname;
        return if !$word_count;
        foreach my $word_idx (0 .. $#charname) {
            my $word = $charname[$word_idx];
            my $word_len = length($word);
            my $min_len = min($MIN_INDEX_LENGTH, $word_len);
            my $max_len = $word_len;
            # printf("        %d: %s (%d) (substring lengths %d .. %d)\n", $word_idx, $word, $word_len, $min_len, $max_len);
            foreach my $substr_len ($min_len .. $max_len) {
                foreach my $substr_idx (0 .. ($word_len - $substr_len)) {
                    my $substr = substr($word, $substr_idx, $substr_len);
                    # printf("            substr(%d, %d) = %s\n", $substr_idx, $substr_len, $substr);
                    my $entry = [$codepoint,
                                 $word_idx,
                                 $word_count,
                                 $word_len,
                                 $substr_idx,
                                 $substr_len,
                                 $which_charname];
                    push(@{$DB->{$substr}}, $entry);
                }
            }
        }
    };
    my $saved_autoflush;
    if (-t 2) {
        $saved_autoflush = set_stderr_autoflush();
    }
    my $charblocks = charblocks();
    my @charblocks = sort { $a->[0][0] <=> $b->[0][0] } values %$charblocks;
    foreach my $charblock (@charblocks) {
        foreach my $range (@$charblock) {
            my ($start, $end, $block_name) = @$range;
            next if $NO_INDEX_BLOCK{$block_name};
            if (-t 2) {
                printf STDERR ("\r\e[K  %s (U+%04X .. U+%04X)\r",
                               $block_name, $start, $end);
            }
            foreach my $codepoint ($start .. $end) {
                # printf("U+%04X\n", $codepoint);
                my @names = get_charnames($codepoint, 1);
                foreach my $i (0 .. $#names) {
                    my $name = $names[$i];
                    # printf("    %s\n", join(" ", @$name));
                    &$add_charname($codepoint, $i, @{$names[$i]});
                }
            }
        }
    }
    if (-t 2) {
        print STDERR ("\r\e[K");
        set_stderr_autoflush($saved_autoflush);
    }
}

sub unicoder_save_db {
    make_path(dirname($JSON_FILENAME));
    my $fh;
    open($fh, '>', $JSON_FILENAME) or return;
    my $json_text = $JSON->encode($DB);
    print $fh $json_text;
    close $fh;
    printf STDERR ("Wrote %d characters (%d substrings)\n", length($json_text), scalar keys %$DB);
    return 1;
}

sub unicoder_load_db {
    my $fh;
    open($fh, '<', $JSON_FILENAME) or return;
    local $/ = undef;
    my $json_text = <$fh>;
    close $fh;
    my $db = $JSON->decode($json_text);
    printf STDERR ("Read %d characters (%d substrings)\n", length($json_text), scalar keys %$db);
    $DB = $db;                  # separate step in case decoding fails
    return 1;
}

sub unicoder_search_db {
    my ($query_words, $more_info) = @_;
    my @query_words = @$query_words;
    @query_words = map { split_words(lc($_)) } @query_words;
    my $query_word_count = scalar @query_words;
    my %raw_results_by_codepoint;
    my %entry_counts_by_query_word;
    foreach my $query_word_idx (0 .. $#query_words) {
        my $query_word = $query_words[$query_word_idx];
        printf("%s:\n", $query_word);
        my @db_entries = @{$DB->{$query_word}};
        if (!scalar @db_entries) {
            printf("    No results.\n");
            continue;
        }
        $entry_counts_by_query_word{$query_word} = scalar @db_entries;
        foreach my $db_entry (@db_entries) {
            my ($codepoint, $word_idx, $word_count, $word_len, $substr_idx, $substr_len, $which_charname) = @$db_entry;
            my $raw_result = { codepoint      => $codepoint,
                               word_idx       => $word_idx,
                               word_count     => $word_count,
                               word_len       => $word_len,
                               substr_idx     => $substr_idx,
                               substr_len     => $substr_len,
                               which_charname => $which_charname,
                               query_word     => $query_word,
                               query_word_idx => $query_word_idx };
            push(@{$raw_results_by_codepoint{$codepoint}}, $raw_result);
        }
    }
    my %scores_by_codepoint;
    foreach my $codepoint (keys %raw_results_by_codepoint) {
        my @raw_results = @{$raw_results_by_codepoint{$codepoint}};
        my $word_matched_count = scalar uniq sort map {
            sprintf("%d.%d", $_->{which_charname}, $_->{word_idx})
        } @raw_results;
        my $highest_score = 0;
        foreach my $raw_result (@raw_results) {
            my $word_idx = $raw_result->{word_idx};
            my $word_count = $raw_result->{word_count};
            my $word_len = $raw_result->{word_len};
            my $substr_idx = $raw_result->{substr_idx};
            my $substr_len = $raw_result->{substr_len};
            my $which_charname = $raw_result->{which_charname};
            my $query_word = $raw_result->{query_word};
            my $query_word_idx = $raw_result->{query_word_idx};
            my $score = 1;
            $score *= 1.1 ** ($word_matched_count / $query_word_count - 1);
            $score *= 1.1 ** ($substr_len / $word_len);
            $score *= 0.9 ** ($substr_idx / (1 + $word_len - $substr_len));
            $score *= 0.8 ** $which_charname;         # primary charname = 1; secondary charname = 0.8
            $score *= (0.5 + 0.5 ** $entry_counts_by_query_word{$query_word});
            $highest_score = max($highest_score, $score);
        }
        $scores_by_codepoint{$codepoint} = $highest_score;
    }
    my @codepoints = sort { $scores_by_codepoint{$b} <=> $scores_by_codepoint{$a} } keys %scores_by_codepoint;
    if ($more_info) {
        return map { { codepoint => $_, score => $scores_by_codepoint{$_} } } @codepoints;
    }
    return @codepoints;
}

1;
