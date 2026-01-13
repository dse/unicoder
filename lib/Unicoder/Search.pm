package Unicoder::Search;
use warnings;
use strict;
use List::Util qw(min uniq max);
use Unicode::UCD qw(charinfo charblocks);
use JSON::XS;
use File::Path qw(make_path);
use File::Basename qw(dirname);
use POSIX qw(round);
use Data::Dumper qw(Dumper);

use lib dirname(__FILE__) . "/..";
use Unicoder::Utils qw(get_charnames split_words set_stderr_autoflush);

use constant ENT_CODEPOINT => 0;
use constant ENT_WORD_IDX => 1;
use constant ENT_WORD_COUNT => 2;
use constant ENT_WORD_LEN => 3;
use constant ENT_SUBSTR_IDX => 4;
use constant ENT_SUBSTR_LEN => 5;
use constant ENT_WHICH_CHARNAME => 6;

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

# It's an index of each query term.
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
            foreach my $substr_len ($min_len .. $max_len) {
                foreach my $substr_idx (0 .. ($word_len - $substr_len)) {
                    my $substr = substr($word, $substr_idx, $substr_len);
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
                my @names = get_charnames($codepoint, 1);
                foreach my $i (0 .. $#names) {
                    my $name = $names[$i];
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
    return 1;
}

sub unicoder_load_db {
    my $fh;
    open($fh, '<', $JSON_FILENAME) or return;
    local $/ = undef;
    my $json_text = <$fh>;
    close $fh;
    my $db = $JSON->decode($json_text);
    $DB = $db; # separate step in case decoding fails and exception is caught
    return 1;
}

# It's a search engine.
sub unicoder_search_db {
    my ($query_words, $more_info) = @_;
    my @query_words = @$query_words;
    @query_words = map { split_words(lc($_)) } @query_words;
    my $query_word_count = scalar @query_words;
    my %raw_results_by_codepoint;
    my %occurrence_count_in_db;

    foreach my $query_word_idx (0 .. $#query_words) {
        my $query_word = $query_words[$query_word_idx];

        while (1) {
            if ($query_word =~ s{^-}{}) {
                # negate
            } elsif ($query_word =~ s{^\^}{}) {
                # start of word
            } elsif ($query_word =~ s{^\+}{}) {
                # require
            } elsif ($query_word =~ s{^=}{}) {
                # whole word
            } else {
                last;
            }
        }

        my @db_entries = @{$DB->{$query_word}};
        foreach my $entry (@db_entries) {
            print("$query_word: @$entry\n");
        }
        if (!scalar @db_entries) {
            continue;
        }
        $occurrence_count_in_db{$query_word} = scalar @db_entries;
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
        my @raw_results_cp = @{$raw_results_by_codepoint{$codepoint}};
        my $highest_score = 0;
        # compute a score for matching the query against each
        # character name (current style and/or Unicode 1.0 style)
        foreach my $which_charname (0, 1) {
            my @raw_results = grep { ($_->{which_charname} // 0) == $which_charname } @raw_results_cp;
            next if !scalar @raw_results;
            my $word_matched_count = scalar uniq sort map { $_->{word_idx} } @raw_results;
            foreach my $raw_result (@raw_results) {
                my $word_idx = $raw_result->{word_idx};
                my $word_count = $raw_result->{word_count};
                my $word_len = $raw_result->{word_len};
                my $substr_idx = $raw_result->{substr_idx};
                my $substr_len = $raw_result->{substr_len};
                my $which_charname = $raw_result->{which_charname};
                my $query_word = $raw_result->{query_word};
                my $query_word_idx = $raw_result->{query_word_idx};
                my $occurrence_count = $occurrence_count_in_db{$query_word};
                $raw_result->{word_matched_count} = $word_matched_count;
                $raw_result->{occurrence_count} = $occurrence_count;
                my $A = $raw_result->{A} = sqrt(sqrt($word_matched_count / $word_count));
                my $B = $raw_result->{B} = sqrt(sqrt($substr_len / $word_len));
                my $C = $raw_result->{C} = sqrt(sqrt(1 - $substr_idx / (1 + $word_len - $substr_len)));
                my $D = $raw_result->{D} = 0.95 ** $which_charname;
                my $E = $raw_result->{E} = sqrt(sqrt(0.5 + 0.5 ** $occurrence_count));
                my $F = $raw_result->{F} = sqrt(sqrt(sqrt($substr_len)));
                my $score = $A * $B * $C * $D * $E * $F;
                $raw_result->{score} = $score;
                $highest_score = max($highest_score, $score);
            }
        }
        $scores_by_codepoint{$codepoint} = $highest_score;
    }
    my @codepoints = sort {
        round(1000 * ($scores_by_codepoint{$b} - $scores_by_codepoint{$a})) || ($a <=> $b)
    } keys %scores_by_codepoint;
    if ($more_info) {
        return map { { codepoint => $_, score => $scores_by_codepoint{$_},
                         raw_results => $raw_results_by_codepoint{$_} } } @codepoints;
    }
    return @codepoints;
}

1;
