unit module IZ4::Screen;

use IZ4::Help;
use IZ4::Register;

#| One result of a command, said three ways: a screen for a person (its
#| title, then chunks with a blank row between them), records for a
#| pipeline (--brief: one tab-separated record a line, nothing else), and
#| a document for a program (--json).  A command fills one in; the form
#| asked for decides what leaves.  Nothing human reaches the records or
#| the document.
class Screen is export {
    has Str $.command = '';
    has Str $.context = '';
    has Str $.heading;              # a title in words of its own, for a short block that is not a command's screen
    has @!chunks;
    has @!records;
    has %.doc is rw;

    method title-line(--> Str) {
        my $words = $!heading // ("iz4 {$!command}" ~ ($!context ne '' ?? ": $!context" !! ''));
        pretty((pretty-on() ?? diamond() ~ ' ' !! '') ~ $words);
    }
    #| A chunk of lines, already in their final shape.
    method lines(*@l) { @!chunks.push: @l.List if @l; self }
    #| Labelled rows in one column: 'foundation    held, word for word'.
    method rows(@pairs) { self.lines(|@pairs.map({ pretty(sprintf('%-13s %s', .key, .value)) })) }
    #| A table: what, where it stands, and the detail, the middle column as wide as its widest.
    method table(@rows) {
        return self unless @rows;
        my $w = @rows.map(*[1].chars).max;
        self.lines(|@rows.map({ pretty(sprintf('%-13s %-*s  %s', .[0], $w, .[1], .[2]).trim-trailing) }));
    }
    method note(Str $s) { self.lines(pretty($s)) }
    #| The one next step, or the line that says nothing waits.
    method next(@steps) { self.lines(pretty(@steps ?? "next:  {@steps[0]}" !! 'next:  nothing waits on you')) }
    #| Several steps that clear the most in order, then what to run again.
    method steps(@steps, Str :$then) {
        return self unless @steps;
        my $n = 0;
        self.lines(pretty('next:'), |@steps.map({ "  {++$n}. $_" }), |("  then: $then again" with $then));
    }
    method record(*@fields) { @!records.push: @fields.map({ (.defined ?? .Str !! '').subst(/\s+/, ' ', :g) }).List; self }

    method screen(Bool :$title = True --> Str) {
        my @parts = @!chunks.map(*.join("\n"));
        @parts.unshift(self.title-line) if $title;
        @parts ?? @parts.join("\n\n") ~ "\n" !! '';
    }
    method brief(--> Str) { @!records.map({ .join("\t") ~ "\n" }).join }
    method json(--> Str) { json-encode(%!doc) ~ "\n" }
    method render(Str $form, Bool :$title = True --> Str) {
        given $form {
            when 'json'  { self.json }
            when 'brief' { self.brief }
            default      { self.screen(:$title) }
        }
    }
}

#| Which form leaves: the document, the records, or the screen.
sub form-of(Bool :$json, Bool :$brief --> Str) is export { $json ?? 'json' !! $brief ?? 'brief' !! 'screen' }
