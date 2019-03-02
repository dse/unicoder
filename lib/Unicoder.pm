package Unicoder;
use warnings;
use strict;
use v5.10.0;

use Unicode::UCD qw(charblocks charscripts charinfo charblock);
use charnames qw();
use Encode::Unicode qw();
use Data::Dumper qw(Dumper);
use open IO => ':locale';
use Encode qw(decode_utf8);

select(STDERR); $| = 1;
select(STDOUT);

use Moo;

has 'dumper'          => (is => 'rw', default => 0);
has 'charBlockHash'   => (is => 'rw');
has 'charScriptHash'  => (is => 'rw');
has 'charBlockNames'  => (is => 'rw');
has 'charScriptNames' => (is => 'rw');
has 'charBlockArray'  => (is => 'rw');
has 'charScriptArray' => (is => 'rw');
has 'noSearch' => (
    is => 'rw', default => sub {
        return {
            'Low Surrogates'                     => 1,
            'High Surrogates'                    => 1,
            'High Private Use Surrogates'        => 1,
            'Private Use Area'                   => 1,
            'Supplementary Private Use Area-A'   => 1,
            'Supplementary Private Use Area-B'   => 1,
            'CJK Unified Ideographs'             => 1,
            'CJK Unified Ideographs Extension B' => 1,
            'CJK Unified Ideographs Extension C' => 1,
            'CJK Unified Ideographs Extension D' => 1,
            'CJK Unified Ideographs Extension E' => 1,
            'CJK Unified Ideographs Extension F' => 1,
            'Tangut'                             => 1,
            'Tangut Components'                  => 1,
        };
    }
);
has clearToEOL => (
    is => 'rw', lazy => 1, default => sub {
        return `tput el`;
    }
);

sub charBlock {
    my ($self, $blockName) = @_;
    $blockName = lc $blockName;
    ($blockName) = grep { lc $_ eq $blockName } @{$self->charBlockNames};
    return unless defined $blockName;
    return $self->charBlockHash->{$blockName};
}

sub charScript {
    my ($self, $scriptName) = @_;
    $scriptName = lc $scriptName;
    ($scriptName) = grep { lc $_ eq $scriptName } @{$self->charScriptNames};
    return unless defined $scriptName;
    return $self->charScriptHash->{$scriptName};
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
                    printf STDERR ("    %s %s%s\r", uplus($codepoint), $subblockname, $self->clearToEOL) if $codepoint % 0x100 == 0 || $codepoint eq $low;
                }
                my $charinfo = charinfo($codepoint);
                my $charname = $charinfo->{name};
                my $charname10 = $charinfo->{unicode10};
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

    my $displayName = join(' ', grep { defined $_ } (
        $charname,
        (defined $charname10 && $charname10 ne '') ? "($charname10)" : undef
    ));

    my $uplus = uplus($codepoint);
    my $char = chr($codepoint);
    if (defined $charname && $charname eq '<control>') {
        $char = '???';
    } elsif ($codepoint == 127) {
        $char = '???';
    } elsif ($codepoint >= 0 && $codepoint <= 31) {
        $char = '???';
    } elsif ($codepoint >= 128 && $codepoint <= 159) {
        $char = '???';
    }

    if (defined $charname) {
        printf("%8s\t%s\t%s\n", $uplus, $char, $displayName);
    }
}

sub listBlocks {
    my ($self) = @_;
    if ($self->dumper) {
        print Dumper $self->charblockHash;
    } else {
        foreach my $blockname (@{$self->charBlockNames}) {
            my $array = $self->charBlock($blockname);
            my $firstLine = $blockname;
            foreach my $subblock (@$array) {
                my ($start, $end, $subblockname) = @$subblock;
                printf(" %8s %8s %7d %s", uplus($start), uplus($end), $end - $start + 1, $firstLine);
                printf(" (%s)", $subblockname) if $subblockname ne $blockname;
                print "\n";
                $firstLine = '"';
            }
        }
    }
}

sub listScripts {
    my ($self) = @_;
    if ($self->dumper) {
        print Dumper $self->charScriptHash;
    } else {
        foreach my $scriptname (@{$self->charScriptNames}) {
            my $array = $self->charScript($scriptname);
            my $firstLine = $scriptname;
            foreach my $subblock (@$array) {
                my ($start, $end, $subscriptname) = @$subblock;
                printf("%-32s %8s %8s", $firstLine, uplus($start), uplus($end));
                printf(" (%s)", $subscriptname) if $subscriptname ne $scriptname;
                print "\n";
                $firstLine = '';
            }
        }
    }
}

sub charInfo {
    my ($self, $char) = @_;
    my $codepoint = $self->codepoint($char);
    if (!defined $codepoint) {
        warn("No character defined by: $char\n");
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
    if ($self->dumper) {
        print Dumper $charinfo;
        return;
    }
    print Dumper $charinfo;
}

sub listBlock {
    my ($self, @blocknames) = @_;
    foreach my $blockname (@blocknames) {
        my $block = $self->charBlock($blockname);
        if (!defined $block) {
            my $codepoint = $self->codepoint($blockname);
            if (defined $codepoint) {
                my $charblock = charblock($codepoint);
                if (defined $charblock) {
                    $blockname = $charblock;
                    $block = $self->charBlock($blockname);
                }
            }
        }
        if (!defined $block) {
            warn("no such block: $blockname\n");
            next;
        }
        printf("# %s\n\n", $blockname);
        foreach my $subblock (@$block) {
            my ($low, $high, $blockname) = @$subblock;
            foreach my $codepoint ($low .. $high) {
                $self->printCharacterLine($codepoint);
            }
        }
        print "\n";
    }
}

sub uplus {
    my ($codepoint) = @_;
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
    if ($spec =~ m{^u\+?([[:xdigit:]]+)$}i) {
        return hex($1);
    }
    if ($spec =~ m{^0?x([[:xdigit:]]+)$}i) {
        return hex($1);
    }
    my $vianame = charnames::vianame(uc $spec);
    if (defined $vianame) {
        return $vianame;
    }
    return;
}

1;
