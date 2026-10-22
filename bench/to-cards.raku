#!/usr/bin/env raku
#| Move every IZ4 in the benchmark to the card form, including the overlays
#| that are deliberately broken (a softened foundation, a hidden character,
#| a look-alike name): each is rendered as cards with its words exactly as
#| they were, so the scenario still does what it did.  The mode line and the
#| word after a name become what each card requires.  Run once, from the
#| repository root; a file already in the card form is left alone.
use lib 'lib';
use IZ4;
use IZ4::Document;

sub items-of(Str $text --> List) {
    # the foundation's sentences as items, as the canonical cards write them: lower case, no full stop
    $text.split(/ '. ' /).map({ .subst(/ '.' $ /, '') }).map({ .substr(0, 1).lc ~ .substr(1) }).List;
}
sub convert(IO::Path $f) {
    my $doc = IZ4::Document.parse($f.slurp);
    return "skip (card)   $f" if $doc.form eq 'card';
    return "skip (named)  $f" if $doc.form eq 'named';
    my @lines = $doc.lines;
    my $drop = "\x[0]drop";
    my sub replace-span(Int $from, Int $to, @new) { @lines[$from - 1] = @new.join("\n"); @lines[$_ - 1] = $drop for $from + 1 .. $to }
    for @lines.kv -> $i, $l { @lines[$i] = $drop if $l ~~ /^ '#' \s* [ 'Vibe' | 'Firm' ] ':' / }
    # the project's own, with the governance their protection meant
    for $doc.invariants -> $inv {
        my $id = $inv.id // 'unnamed.example.com';
        my $change = $doc.protection-of($id) eq 'vibe' ?? CHANGE-FREE !! CHANGE-SIGNED;
        replace-span($inv.line, $inv.last-line, card-lines('PROMISE', $id, $inv.reach // '', ($inv.text,), ($inv.because // '',), $change));
    }
    # every foundation block, as written, even altered: the scenario's words are the scenario
    for $doc.foundation-spans -> ($from, $to) {
        my $head = @lines[$from - 1];
        my $id = $head ~~ / ^ (\S+?) ':' / ?? ~$0 !! next;
        my %clause;
        my $label;
        for @lines[$from .. $to - 1] -> $l {
            if $l ~~ / ^ \h* ('WHERE' | 'ALWAYS' | 'PROTECTS') ':' \h* (.*) $ / { $label = ~$0; %clause{$label} = ~$1 }
            elsif $label.defined && $l !~~ / ^ \h* '#' / { %clause{$label} ~= ' ' ~ $l.trim }
        }
        my $f = FOUNDATION-CARD.first({ .<id> eq $id });
        my @always = $f.defined && normalised(%clause<ALWAYS> // '') eq normalised(FOUNDATION-CLAUSES.first({ .<id> eq $id })<text>)
            ?? $f<always>.list !! items-of(normalised(%clause<ALWAYS> // ''));
        replace-span($from, $to, card-lines('FOUNDATION', $id, normalised(%clause<WHERE> // ''), @always, (normalised(%clause<PROTECTS> // ''),), CHANGE-FOUNDATION));
    }
    my @out = @lines.join("\n").lines.grep(* ne $drop);
    my @tidy; for @out -> $l { @tidy.push($l) unless $l eq '' && @tidy && @tidy.tail eq '' }
    # one blank line before each card heading, as the writer leaves it
    my @spaced; for @tidy -> $l { @spaced.push('') if $l ~~ / ^ [ 'PROMISE' | 'FOUNDATION' ] \h / && @spaced && @spaced.tail ne ''; @spaced.push($l) }
    $f.spurt(@spaced.join("\n") ~ "\n");
    my $after = IZ4::Document.parse($f.slurp);
    "wrote {$after.ok ?? 'ok    ' !! 'errors'} $f" ~ ($after.ok ?? '' !! "  ({$after.errors.head.message.substr(0, 70)})");
}
my @files = 'bench'.IO.dir.grep(*.d).map({ |find-iz4($_) });
sub find-iz4(IO::Path $d --> List) { $d.dir.map({ .d ?? |find-iz4($_) !! .basename eq 'IZ4' ?? $_ !! Empty }).List }
say convert($_) for @files.sort;
