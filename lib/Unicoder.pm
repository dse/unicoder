package Unicoder;
use warnings;
use strict;
use v5.10.0;

use Unicode::UCD qw(charblocks charscripts charinfo charblock
                    charprops_all prop_value_aliases);
use charnames qw();
use Encode::Unicode qw();
use Data::Dumper qw();
use open IO => ':locale';
use Encode qw(decode_utf8);
use Sort::Naturally qw(nsort);
use File::Path qw(make_path);
use File::Basename qw(dirname);
use Text::Wrap qw();
use List::Util qw(max);

select(STDERR); $| = 1;
select(STDOUT);

use Moo;

has 'charBlockHash'   => (is => 'rw');
has 'charScriptHash'  => (is => 'rw');
has 'charBlockNames'  => (is => 'rw');
has 'charScriptNames' => (is => 'rw');
has 'charBlockArray'  => (is => 'rw');
has 'charScriptArray' => (is => 'rw');
has 'noSearch' => (
                   is => 'rw', default => sub {
                       return {
                               'Low Surrogates'                          => 1,
                               'High Surrogates'                         => 1,
                               'High Private Use Surrogates'             => 1,
                               'Private Use Area'                        => 1,
                               'Supplementary Private Use Area-A'        => 1,
                               'Supplementary Private Use Area-B'        => 1,
                               'CJK Unified Ideographs'                  => 1,
                               'CJK Unified Ideographs Extension B'      => 1,
                               'CJK Unified Ideographs Extension C'      => 1,
                               'CJK Unified Ideographs Extension D'      => 1,
                               'CJK Unified Ideographs Extension E'      => 1,
                               'CJK Unified Ideographs Extension F'      => 1,
                               'Tangut'                                  => 1,
                               'Tangut Components'                       => 1,
                               'Variation Selectors Supplement'          => 1,
                               'CJK Unified Ideographs Extension A'      => 1,
                               'CJK Compatibility Ideographs'            => 1,
                               'CJK Compatibility Ideographs Supplement' => 1,
                               'Nushu'                                   => 1,
                              };
                   }
                  );
has clearToEOL => (
    is => 'rw', lazy => 1, default => sub {
        return `tput el`;
    }
);
has format => (is => 'rw', default => 'text');
has base => (is => 'rw', default => 16);

has directory => (is => 'rw', default => "$ENV{HOME}/.unicoder");
has namesList => (is => 'rw');

has numSearchableBlocks => (is => 'rw', lazy => 1, default => \&computeNumSearchableBlocks);

use IO::File;

our $CLEAR_TO_EOL;
BEGIN {
    $CLEAR_TO_EOL = `tput el`;
}

sub progress {
    my ($self, $format, @args) = @_;
    my $msg;
    if (scalar @args) {
        $msg = sprintf($format, @args);
    } else {
        $msg = $format;
    }
    if ($msg =~ m{\n\z}) {
        STDERR->print($msg);
    } else {
        if (-t 2 && $CLEAR_TO_EOL ne '') {
            STDERR->print("\r" . $msg . $CLEAR_TO_EOL);
            STDERR->flush();
        } else {
            STDERR->print($msg . "\n");
        }
    }
}

sub computeNumSearchableBlocks {
    my ($self) = @_;
    my $result = 0;
  block:
    foreach my $block (@{$self->charBlockArray}) {
      subblock:
        foreach my $subblock (@$block) {
            my $subblockname = $subblock->[2];
            next subblock if $self->noSearch->{$subblockname};
            $result += 1;
        }
    }
    return $result;
}

sub charBlockByName {
    my ($self, $blockName) = @_;
    $blockName = $self->normalizeCharBlockName($blockName);
    return unless defined $blockName;
    return $self->charBlockHash->{$blockName};
}

sub charScriptByName {
    my ($self, $scriptName) = @_;
    $scriptName = $self->normalizeCharScriptName($scriptName);
    return unless defined $scriptName;
    return $self->charScriptHash->{$scriptName};
}

sub normalizeCharBlockName {
    my ($self, $blockName) = @_;
    $blockName = lc $blockName;
    ($blockName) = grep { lc $_ eq $blockName } @{$self->charBlockNames};
    return unless defined $blockName;
    return $blockName;
}

sub normalizeCharScriptName {
    my ($self, $scriptName) = @_;
    $scriptName = lc $scriptName;
    ($scriptName) = grep { lc $_ eq $scriptName } @{$self->charScriptNames};
    return unless defined $scriptName;
    return $scriptName;
}

sub buildDatabase {
    my ($self) = @_;
    my $dbFile = $self->directory . '/db/unicoder.pl';
    my $dbFile2 = $self->directory . '/db/unicoder2.pl';

    my $fh;
    make_path(dirname($dbFile));
    if (!open($fh, '>', $dbFile)) {
        warn("cannot write $dbFile: $!\n");
        return;
    }

    my $fh2;
    make_path(dirname($dbFile2));
    if (!open($fh2, '>', $dbFile2)) {
        warn("cannot write $dbFile2: $!\n");
        return;
    }

    my $hash = {
                charname => {},
                charname10 => {}
               };

    my $total = $self->numSearchableBlocks;
    my $count = 0;
  block:
    foreach my $block (@{$self->charBlockArray}) {
      subblock:
        foreach my $subblock (@$block) {
            my ($low, $high, $subblockname) = @$subblock;
            next subblock if $self->noSearch->{$subblockname};
            $count += 1;
            if (-t 2) {
                $self->progress("buildDatabase: ($count/$total) $subblockname");
            }
            foreach my $codepoint ($low .. $high) {
                my $charinfo = charinfo($codepoint);
                my $charname = $charinfo->{name};
                my $charname10 = $charinfo->{unicode10};
                $charname   = undef if defined $charname   && $charname   !~ m{\S};
                $charname10 = undef if defined $charname10 && $charname10 !~ m{\S};
                next if !defined $charname && !defined $charname10;
                $charname   = lc $charname   if defined $charname;
                $charname10 = lc $charname10 if defined $charname10;
                my @charname;
                my @charname10;
                @charname   = grep { defined $_ && $_ ne '' } split(qr{[^A-Za-z0-9]+}, $charname)   if defined $charname;
                @charname10 = grep { defined $_ && $_ ne '' } split(qr{[^A-Za-z0-9]+}, $charname10) if defined $charname10;
                my $i;
                $i = 0;
                foreach my $word (@charname) {
                    $i += 1;
                    $hash->{charname}->{$word}->{$codepoint} = $i;
                }
                $i = 0;
                foreach my $word (@charname10) {
                    $i += 1;
                    $hash->{charname10}->{$word}->{$codepoint} = $i;
                }
            }
        }
    }
    if (-t 2) {
        $self->progress("\n");
    }

    print $fh Dumper($hash);
    if (!close($fh)) {
        die("cannot close $dbFile: $!\n");
    }

    print $fh2 CompactDumper($hash);
    if (!close($fh2)) {
        die("cannot close $dbFile2: $!\n");
    }
}

sub buildTextList {
    my ($self) = @_;
    my $dbFile = $self->directory . '/db/unicoder.txt';

    my $fh;
    make_path(dirname($dbFile));
    if (!open($fh, '>', $dbFile)) {
        warn("cannot write $dbFile: $!\n");
        return;
    }

    my $total = $self->numSearchableBlocks;
    my $count = 0;
  block:
    foreach my $block (@{$self->charBlockArray}) {
      subblock:
        foreach my $subblock (@$block) {
            my ($low, $high, $subblockname) = @$subblock;
            next subblock if $self->noSearch->{$subblockname};
            $count += 1;
            if (-t 2) {
                $self->progress("buildTextList: ($count/$total) $subblockname");
            }
            foreach my $codepoint ($low .. $high) {
                my $charinfo = charinfo($codepoint);
                my $charname = $charinfo->{name};
                my $charname10 = $charinfo->{unicode10};
                $charname   = undef if defined $charname   && $charname   !~ m{\S};
                $charname10 = undef if defined $charname10 && $charname10 !~ m{\S};
                next if !defined $charname && !defined $charname10;
                printf $fh ("%-8s", sprintf("U+%04X", $codepoint));
                if (($codepoint >= 0 && $codepoint < 32) || ($codepoint >= 127 && $codepoint < 160)) {
                    print $fh ("  ?");
                } else {
                    printf $fh ("  %s", chr($codepoint));
                }
                printf $fh ("  %s", $charname)     if defined $charname;
                printf $fh ("  (%s)", $charname10) if defined $charname10;
                print $fh ("\n");
            }
        }
    }
    if (-t 2) {
        $self->progress("\n");
    }
    if (!close($fh)) {
        die("cannot close $dbFile: $!\n");
    }
}

sub buildTextDatabase {
    my ($self) = @_;
    my $dbFile = $self->directory . '/db/unicoder.db.txt';

    my $fh;
    make_path(dirname($dbFile));
    if (!open($fh, '>', $dbFile)) {
        warn("cannot write $dbFile: $!\n");
        return;
    }

    my $hash = {
                charname => {},
                charname10 => {}
               };

    my $total = $self->numSearchableBlocks;
    my $count = 0;
  block:
    foreach my $block (@{$self->charBlockArray}) {
      subblock:
        foreach my $subblock (@$block) {
            my ($low, $high, $subblockname) = @$subblock;
            next subblock if $self->noSearch->{$subblockname};
            $count += 1;
            if (-t 2) {
                $self->progress("buildTextDatabase: ($count/$total) $subblockname");
            }
            foreach my $codepoint ($low .. $high) {
                my $charinfo = charinfo($codepoint);
                my $charname = $charinfo->{name};
                my $charname10 = $charinfo->{unicode10};
                $charname   = undef if defined $charname   && $charname   !~ m{\S};
                $charname10 = undef if defined $charname10 && $charname10 !~ m{\S};
                next if !defined $charname && !defined $charname10;
                $charname   = lc $charname   if defined $charname;
                $charname10 = lc $charname10 if defined $charname10;
                my @charname;
                my @charname10;
                @charname   = grep { defined $_ && $_ ne '' } split(qr{[^A-Za-z0-9]+}, $charname)   if defined $charname;
                @charname10 = grep { defined $_ && $_ ne '' } split(qr{[^A-Za-z0-9]+}, $charname10) if defined $charname10;
                my $i;
                $i = 0;
                foreach my $word (@charname) {
                    $i += 1;
                    say $fh "1 $word $codepoint $i";
                }
                $i = 0;
                foreach my $word (@charname10) {
                    $i += 1;
                    say $fh "2 $word $codepoint $i";
                }
            }
        }
    }
    if (-t 2) {
        $self->progress("\n");
    }
    if (!close($fh)) {
        die("cannot close $dbFile: $!\n");
    }
}

sub listAll {
    my ($self) = @_;

    my %lengths = $self->maxLengths();
    my $max1 = $lengths{subblockname};
    my $max2 = $lengths{charname};

  block:
    foreach my $block (@{$self->charBlockArray}) {
      subblock:
        foreach my $subblock (@$block) {
            my ($low, $high, $subblockname) = @$subblock;
            next subblock if $self->noSearch->{$subblockname};
            foreach my $codepoint ($low .. $high) {
                my $charinfo = charinfo($codepoint);
                my $charname = $charinfo->{name};
                my $charname10 = $charinfo->{unicode10};
                $charname   = undef if defined $charname   && $charname   !~ m{\S};
                $charname10 = undef if defined $charname10 && $charname10 !~ m{\S};
                next if !defined $charname && !defined $charname10;
                printf("%-*s", $max1, $subblockname);
                printf("   %-*s", 8, sprintf("   U+%04X", $codepoint));
                printf("   %-*s", $max2, $charname // '-');
                printf("   %s", $charname10) if defined $charname10;
                print("\n");
            }
        }
    }
}

sub maxLengths {
    my ($self) = @_;

    my $max1 = 0;
    my $max2 = 0;
    my $max3 = 0;
  block:
    foreach my $block (@{$self->charBlockArray}) {
      subblock:
        foreach my $subblock (@$block) {
            my ($low, $high, $subblockname) = @$subblock;
            next subblock if $self->noSearch->{$subblockname};
            $max1 = max($max1, length $subblockname);
            foreach my $codepoint ($low .. $high) {
                my $charinfo = charinfo($codepoint);
                my $charname = $charinfo->{name};
                my $charname10 = $charinfo->{unicode10};
                $charname   = undef if defined $charname   && $charname   !~ m{\S};
                $charname10 = undef if defined $charname10 && $charname10 !~ m{\S};
                next if !defined $charname && !defined $charname10;
                $max2 = max($max2, length $charname)   if defined $charname;
                $max3 = max($max3, length $charname10) if defined $charname10;
            }
        }
    }

    my $result = {
                  subblockname => $max1,
                  charname => $max2,
                  charname10 => $max3
                 };
    return %$result if wantarray;
    return $result;
}

sub buildSqliteDatabase {
    my ($self) = @_;
    my $dbFile = $self->directory . '/unicoder.sqlite';
}

sub BUILD {
    my ($self) = @_;
    my $charblocks = charblocks();
    my $charscripts = charscripts();
    $self->charBlockHash($charblocks);
    $self->charScriptHash($charscripts);
    $self->charBlockNames([
        sort {
            $charblocks->{$a}->[0]->[0] <=> $charblocks->{$b}->[0]->[0]
        } keys %$charblocks
    ]);
    $self->charScriptNames([
        sort {
            $charscripts->{$a}->[0]->[0] <=> $charscripts->{$b}->[0]->[0]
        } keys %$charscripts
    ]);
    $self->charBlockArray([
        map { $charblocks->{$_} } @{$self->charBlockNames}
    ]);
    $self->charScriptArray([
        map { $charscripts->{$_} } @{$self->charScriptNames}
    ]);
}

sub search {
    my ($self, @keywords) = @_;

    my @searches;
    foreach my $keyword (@keywords) {
        my $number = 0;
        my $word = 0;
        while (1) {
            if ($keyword =~ s{\A\s*\+\s*}{}) {
                $number = 1;
            } elsif ($keyword =~ s{\A\s*\-\s*}{}) {
                $number = -1;
            } elsif ($keyword =~ s{^not:}{}i) {
                $number = -1;
            } elsif ($keyword =~ s{^require:}{}i) {
                $number = 1;
            } elsif ($keyword =~ s{^word:}{}i) {
                $word = 1;
            } else {
                last;
            }
        }
        $keyword =~ s{\A\s+}{};
        $keyword =~ s{\s+\z}{};
        $keyword = uc($keyword);
        my $rx = join('[^[:alnum:]]+', map { quotemeta($_) } split(qr{\s+}, $keyword));
        if ($word) {
            $rx = "\\b" . $rx . "\\b";
        }
        $rx = qr{$rx};
        push(@searches, [$rx, $number]);
    }

    my @results;

  block:
    foreach my $block (@{$self->charBlockArray}) {
      subblock:
        foreach my $subblock (@$block) {
            my ($low, $high, $subblockname) = @$subblock;
            next subblock if $self->noSearch->{$subblockname};
          codepoint:
            foreach my $codepoint ($low .. $high) {
                if (-t 2) {
                    printf STDERR ("    %s %s%s\r",
                                   $self->uplus($codepoint),
                                   $subblockname,
                                   $self->clearToEOL) if $codepoint % 0x100 == 0 || $codepoint eq $low;
                }
                my $charinfo = charinfo($codepoint);
                my $charname = $charinfo->{name};
                my $charname10 = $charinfo->{unicode10};
                $charname   = undef if defined $charname && $charname   !~ m{\S};
                $charname10 = undef if defined $charname && $charname10 !~ m{\S};
                next codepoint if !defined $charname;
                my $codepointMatches = 0;
                my $weight = 0;
                foreach my $search (@searches) {
                    my ($rx, $number) = @$search;
                    my $keywordMatches = (defined $charname && $charname =~ $rx) || (defined $charname10 && $charname10 =~ $rx);
                    if ($number == -1) { # negated
                        next codepoint if $keywordMatches;
                    } elsif ($number == 1) { # required
                        next codepoint unless $keywordMatches;
                        $weight += 1;
                        $codepointMatches = 1;
                    } else {
                        if ($keywordMatches) {
                            $codepointMatches = 1;
                            $weight += 1;
                        }
                    }
                }
                push(@results, [$codepoint, $weight]) if $codepointMatches;
            }
        }
    }
    if (-t 2) {
        printf STDERR ("Done searching.%s\n", $self->clearToEOL);
    }

    @results = sort {
        ($b->[1] <=> $a->[1]) || ($a->[0] <=> $b->[0])
    } @results;

    foreach my $result (@results) {
        my $codepoint = $result->[0];
        my $weight = $result->[1];
        $self->printCharacterLine($codepoint, $weight);
    }
}

sub printCharacterLine {
    my ($self, $codepoint, $weight) = @_;
    my $charinfo = charinfo($codepoint);
    my $charname = $charinfo->{name};
    my $charname10 = $charinfo->{unicode10};
    $charname   = undef if $charname   !~ m{\S};
    $charname10 = undef if $charname10 !~ m{\S};
    my $displayName = join(' ', grep { defined $_ } (
        $charname,
        (defined $charname10 && $charname10 ne '') ? "($charname10)" : undef
    ));
    my $uplus = $self->uplus($codepoint);
    my $charDisplayed = $self->charDisplayed($codepoint) // '???';
    if (defined $charname) {
        if ($self->isDelimiterSeparated) {
            $self->printDelimiterSeparatedLine($uplus, $charDisplayed, $displayName);
        } else {
            printf("%-8s    %-3s     %s\n", $uplus, $charDisplayed, $displayName);
        }
    }
}

sub charDisplayed {
    my ($self, $codepoint) = @_;
    return undef if $codepoint == 127;
    return undef if $codepoint >= 0 && $codepoint < 32;
    return undef if $codepoint >= 128 && $codepoint < 160;
    my $charinfo = charinfo($codepoint);
    my $charname = $charinfo->{name};
    return undef if defined $charname && $charname eq '<control>';
    my $char = chr($codepoint);
    return undef if $char =~ m{^\P{Print}$};
    return $char;
}

sub listBlocks {
    my ($self) = @_;
    if ($self->format eq 'dumper') {
        print Dumper($self->charblockHash);
    } else {
        foreach my $blockname (@{$self->charBlockNames}) {
            my $array = $self->charBlockByName($blockname);
            my $firstLine = $blockname;
            foreach my $subblock (@$array) {
                my ($start, $end, $subblockname) = @$subblock;
                if ($self->isDelimiterSeparated) {
                    my (@line) = ($self->uplus($start), $self->uplus($end), $end - $start + 1, $firstLine);
                    if ($firstLine ne '') {
                        push(@line, $subblockname) if $subblockname ne $blockname;
                    }
                    $self->printDelimiterSeparatedLine(@line);
                } else {
                    printf("%-8s    %-8s    %-7d %s", $self->uplus($start), $self->uplus($end), $end - $start + 1, $firstLine);
                    if ($firstLine ne '') {
                        printf(" (%s)", $subblockname) if $subblockname ne $blockname;
                    }
                    print "\n";
                }
                $firstLine = '';
            }
        }
    }
}

sub listScripts {
    my ($self) = @_;
    if ($self->format eq 'dumper') {
        print Dumper($self->charScriptHash);
    } else {
        foreach my $scriptname (@{$self->charScriptNames}) {
            my $array = $self->charScriptByName($scriptname);
            my $firstLine = $scriptname;
            foreach my $subblock (@$array) {
                my ($start, $end, $subscriptname) = @$subblock;
                if ($self->isDelimiterSeparated) {
                    my (@line) = ($self->uplus($start), $self->uplus($end), $end - $start + 1, $firstLine);
                    if ($firstLine ne '') {
                        push(@line, $subscriptname) if $subscriptname ne $scriptname;
                    }
                    $self->printDelimiterSeparatedLine(@line);
                } else {
                    printf("%-8s    %-8s    %-7d %s", $self->uplus($start), $self->uplus($end), $end - $start + 1, $firstLine);
                    if ($firstLine ne '') {
                        printf(" (%s)", $subscriptname) if $subscriptname ne $scriptname;
                    }
                    print "\n";
                }
                $firstLine = '';
            }
        }
    }
}

sub charInfo {
    my ($self, $arg) = @_;
    my $codepoint = $self->codepoint($arg);
    if (!defined $codepoint) {
        warn("No character defined by: $arg\n");
        return;
    }
    my $charname = charnames::viacode($codepoint);
    if (!defined $charname) {
        warn("No character name for codepoint: $codepoint\n");
        return;
    }
    my $charinfo = charinfo($codepoint);
    if (!$charinfo) {
        warn("No character info for codepoint: $codepoint\n");
        return;
    }

    $self->getNamesList();
    my $namesList = $self->namesList->{codepoints}->[$codepoint];

    if ($self->format eq 'dumper') {
        if ($namesList) {
            $charinfo->{namesList} = $namesList;
        }
        print Dumper($charinfo);
        return;
    }

    foreach my $key (nsort keys %$charinfo) {
        if ($self->isDelimiterSeparated) {
            $self->printDelimiterSeparatedLine($key, $charinfo->{$key});
        } else {
            printf("%-29s   %s\n", $key, $charinfo->{$key});
        }
    }

    local $Text::Wrap::columns = 79;
    if (eval { scalar @{$namesList->{alternativeNames}} }) {
        print("Alternative Names:\n");
        foreach my $entry (@{$namesList->{alternativeNames}}) {
            print(Text::Wrap::wrap('-   ', '    ', $entry->{text}), "\n");
        }
    }
    if (eval { scalar @{$namesList->{characterNameAliases}} }) {
        print("Character Name Aliases:\n");
        foreach my $entry (@{$namesList->{characterNameAliases}}) {
            print(Text::Wrap::wrap('-   ', '    ', $entry->{text}), "\n");
        }
    }
    if (eval { scalar @{$namesList->{informativeNotes}} }) {
        print("Informative Notes:\n");
        foreach my $entry (@{$namesList->{informativeNotes}}) {
            print(Text::Wrap::wrap('-   ', '    ', $entry->{text}), "\n");
        }
    }
    if (eval { scalar @{$namesList->{crossReferences}} }) {
        print("Cross References:\n");
        foreach my $entry (@{$namesList->{crossReferences}}) {
            if ($entry->{codepoint}) {
                my $hexCodepoint = sprintf('U+%04X', $entry->{codepoint});
                my $charinfo = charinfo($entry->{codepoint});
                printf("-   %-8s  %s  %s\n",
                       $hexCodepoint,
                       chr($entry->{codepoint}),
                       $charinfo->{name});
            } else {
                print(Text::Wrap::wrap('-   ', '    ', $entry->{text}), "\n");
            }
        }
    }
    if (eval { scalar @{$namesList->{compatibilityDecompositions}} }) {
        print("Compatibility Decompositions:\n");
        foreach my $entry (@{$namesList->{compatibilityDecompositions}}) {
            print(Text::Wrap::wrap('-   ', '    ', $entry->{text}), "\n");
        }
    }
    if (eval { scalar @{$namesList->{canonicalDecompositions}} }) {
        print("Canonical Decompositions:\n");
        foreach my $entry (@{$namesList->{canonicalDecompositions}}) {
            print(Text::Wrap::wrap('-   ', '    ', $entry->{text}), "\n");
        }
    }
    if (eval { scalar @{$namesList->{standardizedVariationSequences}} }) {
        print("Standardized Variation Sequences:\n");
        foreach my $entry (@{$namesList->{standardizedVariationSequences}}) {
            print(Text::Wrap::wrap('-   ', '    ', $entry->{text}), "\n");
        }
    }
}

sub charProperties {
    my ($self, $arg) = @_;
    my $codepoint = $self->codepoint($arg);
    if (!defined $codepoint) {
        warn("No character defined by: $arg\n");
        return;
    }
    my $charprops = charprops_all($codepoint);
    if ($self->format eq 'dumper') {
        print(Dumper($charprops));
        return;
    }
    foreach my $key (nsort keys %$charprops) {
        if ($self->isDelimiterSeparated) {
            $self->printDelimiterSeparatedLine($key, $charprops->{$key});
        } else {
            printf("%-29s   %s\n", $key, $charprops->{$key});
        }
    }
}

sub listBlock {
    my ($self, @args) = @_;
    foreach my $arg (@args) {
        my ($block, $blockname) = $self->getBlock($arg);
        if (!defined $block) {
            warn("no such block, codepoint, or character: $blockname\n");
            next;
        }
        printf("# %s\n", $blockname);
        foreach my $subblock (@$block) {
            my ($low, $high, $blockname) = @$subblock;
            foreach my $codepoint ($low .. $high) {
                $self->printCharacterLine($codepoint);
            }
        }
    }
}

sub listBlockTable {
    my ($self, @args) = @_;
    foreach my $arg (@args) {
        my ($block, $blockname) = $self->getBlock($arg);
        if (!defined $block) {
            warn("no such block, codepoint, or character: $blockname\n");
            next;
        }
        printf("# %s\n", $blockname);

        # header
        if ($self->isDelimiterSeparated) {
            $self->printDelimiterSeparatedLine('', '0' .. '9', 'A' .. 'F');
        } else {
            print(' ' x 11);
            foreach my $c (0 .. 15) {
                printf(' %2X ', $c);
            }
            print("\n");
        }

        # header border
        if (!$self->isDelimiterSeparated) {
            print(' ' x 11 . ' ---' x 16 . "\n");
        }

        foreach my $subblock (@$block) {
            my ($low, $high, $blockname) = @$subblock;
            my $llow = $low & ~0x0f;
            my $hhigh = $high | 0x0f;
            for (my $row = $llow; $row <= $hhigh; $row += 16) {
                if ($self->isDelimiterSeparated) {
                    $self->printDelimiterSeparatedLine(
                        sprintf('U+%04X', $row),
                        map { $self->charDisplayed($_) // '???' } ($row .. $row + 15)
                    );
                } else {
                    printf("%-11s", sprintf('U+%04X', $row));
                    foreach my $c (0 .. 15) {
                        my $codepoint = $row + $c;
                        my $charDisplayed = $self->charDisplayed($codepoint);
                        if (defined $charDisplayed) {
                            printf("  %s ", $charDisplayed);
                        } else {
                            print(' ???');
                        }
                    }
                    print("\n");
                }
            }
        }
    }
}

sub getBlock {
    my ($self, $arg) = @_;
    my $blockname;
    my $block = $self->charBlockByName($arg);
    if (defined $block) {
        $blockname = $self->normalizeCharBlockName($arg);
    } else {
        my $codepoint = $self->codepoint($arg);
        if (defined $codepoint) {
            my $charblock = charblock($codepoint);
            if (defined $charblock) {
                $blockname = $charblock;
                $block = $self->charBlockByName($blockname);
            }
        } else {
            return;
        }
    }
    if (!defined $block) {
        return;
    }
    return ($block, $blockname) if wantarray;
    return $block;
}

sub uplus {
    my ($self, $codepoint) = @_;
    if ($self->base == 10) {
        return sprintf('%d', $codepoint);
    }
    if ($self->base == 8) {
        my $octal = '0' . sprintf('%o', $codepoint);
        $octal =~ s{^00+}{0};
        return $octal;
    }
    return sprintf('U+%04X', $codepoint);
}

sub codepoint {
    my ($self, $spec) = @_;
    if ($spec =~ m{^\d+$}) {
        return 0 + $spec;
    }
    if (length($spec) == 1) {
        return ord($spec);
    }
    if ($spec =~ m{^u\+?([[:xdigit:]]+)($|[^[:alnum:]])}i) {
        return hex($1);
    }
    if ($spec =~ m{^0?x([[:xdigit:]]+)($|[^[:alnum:]])}i) {
        return hex($1);
    }
    my $vianame = charnames::vianame(uc $spec);
    if (defined $vianame) {
        return $vianame;
    }
    return;
}

sub fetchNamesList {
    my ($self) = @_;
    if ($self->namesList) {
        return;
    }
    my $url = 'https://unicode.org/Public/UNIDATA/NamesList.txt';
    my $cacheDir = $self->directory . '/' . 'cache';
    make_path($cacheDir);

    my $ua;

    eval {
        require LWP::UserAgent::Cached;
        my $ua = LWP::UserAgent::Cached->new(cache_dir => $cacheDir);
    };
    if ($@) {
        eval {
            require LWP::UserAgent;
            my $ua = LWP::UserAgent->new(cache_dir => $cacheDir);
            warn("NOTICE: Please install LWP::UserAgent::Cached if you want caching.\n");
        };
    }
    if ($@) {
        warn("Neither LWP::UserAgent::Cached nor LWP::UserAgent found.\n");
        warn("Please install one of them, preferably the former.\n");
    }

    warn("Fetching $url ...\n");
    my $response = $ua->get($url);
    warn("    Done.\n");
    if (!$response->is_success) {
        $self->namesList(undef);
        return;
    }
    $self->namesList($response->decoded_content);
}

sub buildNamesList {
    my ($self) = @_;
    if ($self->namesList && ref $self->namesList eq 'HASH') {
        return;
    }
    my $content = $self->namesList;
    my $hash = {};
    local $_;
    my $namesList = {};
    my $codepoint;
    foreach (split(/\r?\n/, $content)) {
        if (m{^\;}) {
            next;
        } elsif (m{^([[:alnum:]]+)\s+(.*)$}) {
            ($codepoint, my $name) = ($1, $2);
            $codepoint = hex($codepoint);
            $namesList->{codepoints}->[$codepoint]->{name} = $name;
            $namesList->{codepoints}->[$codepoint]->{codepoint} = $codepoint;
            $namesList->{codepoints}->[$codepoint]->{hexCodepoint} = sprintf('U+%04X', $codepoint);
        } elsif (m{^\S}) {
            $codepoint = undef;
            next;
        } elsif (m{^\s+\=\s+}) {
            if (!defined $codepoint) {
                next;
            }
            push(@{$namesList->{codepoints}->[$codepoint]->{alternativeNames}}, { text => $' });
        } elsif (m{^\s+\%\s+}) {
            if (!defined $codepoint) {
                next;
            }
            push(@{$namesList->{codepoints}->[$codepoint]->{characterNameAliases}}, { text => $' });
        } elsif (m{^\s+\*\s+}) {
            if (!defined $codepoint) {
                next;
            }
            push(@{$namesList->{codepoints}->[$codepoint]->{informativeNotes}}, { text => $' });
        } elsif (m{^\s+x\s+}) {
            my $crossReference = $';
            if (!defined $codepoint) {
                next;
            }
            if ($crossReference =~ m{^\s*\(\s*
                                     (.*)
                                     \s*-\s*
                                     ([[:xdigit:]]+)
                                     \s*\)\s*$}x) {
                my ($name, $codepointXref) = ($1, $2);
                $codepointXref = hex($codepointXref);
                push(@{$namesList->{codepoints}->[$codepoint]->{crossReferences}}, {
                    text => $crossReference,
                    name => uc($name),
                    codepoint => $codepointXref,
                    hexCodepoint => sprintf('U+%04X', $codepointXref),
                });
            } else {
                push(@{$namesList->{codepoints}->[$codepoint]->{crossReferences}}, {
                    text => $crossReference
                });
            }
        } elsif (m{^\s+\#\s+}) {
            if (!defined $codepoint) {
                next;
            }
            push(@{$namesList->{codepoints}->[$codepoint]->{compatibilityDecompositions}}, { text => $' });
        } elsif (m{^\s+\:\s+}) {
            if (!defined $codepoint) {
                next;
            }
            push(@{$namesList->{codepoints}->[$codepoint]->{canonicalDecompositions}}, { text => $' });
        } elsif (m{^\s+\~\s+}) {
            if (!defined $codepoint) {
                next;
            }
            push(@{$namesList->{codepoints}->[$codepoint]->{standardizedVariationSequences}}, { text => $' });
        }
    }
    $self->namesList($namesList);
}

sub getNamesList {
    my ($self) = @_;
    $self->fetchNamesList();
    $self->buildNamesList();
}

sub isDelimiterSeparated {
    my $self = shift;
    return $self->format eq 'tsv' || $self->format eq 'csv';
}

has csv => (is => 'rw');

sub printDelimiterSeparatedLine {
    my ($self, @line) = @_;
    if ($self->format eq 'tsv') {
        print(join("\t", @line), "\n");
        return;
    }
    if ($self->format eq 'csv') {
        if (!$self->csv) {
            require Text::CSV;
            $self->csv(Text::CSV->new({ binary => 1, auto_diag => 1 }));
        }
        $self->csv->say(\*STDOUT, \@line);
        return;
    }
}

sub eachCharacter {
    my ($self, $arg) = @_;
    my $codepoint = $self->codepoint($arg);
    if (!defined $codepoint) {
        warn("No character defined by: $arg\n");
        return;
    }
    my $charname = charnames::viacode($codepoint);
    if (!defined $charname) {
        warn("No character name for codepoint: $codepoint\n");
        return;
    }
    my $charinfo = charinfo($codepoint);
    if (!$charinfo) {
        warn("No character info for codepoint: $codepoint\n");
        return;
    }
    $self->printCharacterLine($codepoint);
}

sub printCharacterName {
    my ($self, $arg) = @_;
    my $codepoint = $self->codepoint($arg);
    if (!defined $codepoint) {
        warn("No character defined by: $arg\n");
        if (!-t 1) {
            print("\n");
        }
        return;
    }
    my $charname = charnames::viacode($codepoint);
    if (!defined $charname) {
        warn("No character name for codepoint: $codepoint\n");
        if (!-t 1) {
            print("\n");
        }
        return;
    }
    my $charinfo = charinfo($codepoint);
    if (!$charinfo) {
        warn("No character info for codepoint: $codepoint\n");
        if (!-t 1) {
            print("\n");
        }
        return;
    }
    my $charname10 = $charinfo->{unicode10};
    my $displayName = join(' ', grep { defined $_ } (
        $charname,
        (defined $charname10 && $charname10 ne '') ? "($charname10)" : undef
    ));
    printf("%s\n", $displayName);
}

sub printBlockName {
    my ($self, $arg) = @_;
    my $codepoint = $self->codepoint($arg);
    if (!defined $codepoint) {
        warn("No character defined by: $arg\n");
        if (!-t 1) {
            print("\n");
        }
        return;
    }
    my $charblock = charblock($codepoint);
    if (!defined $charblock) {
        warn("No character block for codepoint: $codepoint\n");
        if (!-t 1) {
            print("\n");
        }
        return;
    }
    printf("%s\n", $charblock);
    return;
    my ($short, $full, @other) = prop_value_aliases('block', $charblock);
    printf("%s\n", $short);
}

sub Dumper {
    my (@args) = @_;
    local $Data::Dumper::Indent   = 1;
    local $Data::Dumper::Terse    = 1;
    local $Data::Dumper::Deepcopy = 1;
    local $Data::Dumper::Sortkeys = 1;
    local $Data::Dumper::Useqq    = 1;
    return Data::Dumper::Dumper(@args);
}

sub CompactDumper {
    my (@args) = @_;
    local $Data::Dumper::Indent   = 0;
    local $Data::Dumper::Terse    = 1;
    local $Data::Dumper::Deepcopy = 1;
    local $Data::Dumper::Sortkeys = 1;
    return Data::Dumper::Dumper(@args);
}

1;
