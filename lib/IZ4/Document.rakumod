unit class IZ4::Document;

#| IZ4 means Is For.  A file answers three questions and nothing else:
#| what is this software for, who is it for, and what must remain true
#| for it to keep serving them.  It is deliberately incomplete: enduring
#| intent, never everything known about the software.
#|
#|     IZ4
#|
#|     IS FOR WHAT
#|     Helping people find work they love to do.
#|
#|     IS FOR WHO
#|     People looking for work.
#|
#|     INVARIANT 5
#|     People control whether their profile is visible.
#|
#|     BECAUSE
#|     Looking for work should not mean surrendering privacy.
#|
#| Every IZ4 inherits the foundation, Invariants 0-4, without repeating
#| it.  Those numbers are reserved; a project's own invariants begin at 5.
#|
#| The earlier format ('gist:', 'invariants:' and friends, indented '- '
#| entries) is still read, as the legacy dialect, so no existing file
#| stops working; 'iz4 migrate' converts one explicitly.

# ------------------------------------------------------------ foundation

#| The inherited foundation.  Restructured on 2026-09-17 from the single
#| Invariant 0 text below into five parts, with every protection of that
#| text kept: thriving and dignity, no disposable people, no harm, humans
#| in charge (explain, challenge, correct, stop safely), honesty including
#| what is uncertain or blocked, the safe pause on conflict, and nothing
#| may weaken it.  Stating a rule, or hashing it, does not make software
#| obey it.
constant FOUNDATION is export = (
    %( number => 0, name => 'HUMANS FIRST',
       text => "Help people thrive, and respect each person's dignity. No "
             ~ 'objective or claimed greater good makes a person disposable.' ),
    %( number => 1, name => 'DO NO HARM',
       text => 'Do not harm people, or help anyone harm them.' ),
    %( number => 2, name => 'HUMAN AGENCY',
       text => 'Keep humans in charge of consequential actions: explain them, '
             ~ 'let people challenge and correct them, and stop safely when asked.' ),
    %( number => 3, name => 'HONESTY',
       text => 'Be honest about what this software is, what it knows, what it '
             ~ 'has done, and what remains uncertain or blocked.' ),
    %( number => 4, name => 'THE FOUNDATION HOLDS',
       text => 'When an objective, instruction or other invariant conflicts with '
             ~ 'Invariants 0 to 3, preserve them, report the conflict, and safely '
             ~ 'pause the affected action. No other entry may weaken Invariants 0 to 4.' ),
);

#| Project invariants begin here; everything below is inherited.
constant FIRST-PROJECT-NUMBER is export = 5;

#| The canonical bytes the digest covers: one line per foundation
#| invariant, no trailing newline.
constant FOUNDATION-TEXT is export =
    FOUNDATION.map({ "Invariant {.<number>} - {.<name>}: {.<text>}" }).join("\n");

#| sha256 of FOUNDATION-TEXT.  A test pins it to the bytes.
constant FOUNDATION-DIGEST is export =
    'ca4681a7c22c46dbef0f267336c761bdb523c739b1ab3ae8fa375fd85406347a';

#| The single Invariant 0 text the foundation replaced.  Legacy files
#| repeat it; it is recognised, never written.
constant LEGACY-INVARIANT-ZERO is export =
    "Invariant 0: humans first. Help people thrive, and respect each person's "
    ~ 'dignity. Do no harm, and no greater good makes a person disposable. Keep '
    ~ 'humans in charge: explain consequential actions, accept challenge and '
    ~ 'correction, and stop safely when asked. When an objective conflicts with '
    ~ 'these protections, preserve them, report the conflict, and safely pause '
    ~ 'the affected action. Be honest about what this is, what it knows, what '
    ~ 'it has done, and what remains uncertain or blocked. No other entry may '
    ~ 'weaken this.';
constant LEGACY-INVARIANT-ZERO-DIGEST is export =
    '1af8b123edd8b27afba34c2ee385bb649c6eaed25647e7240f9f26cd440472f3';

#| The designations legacy files use for Invariant 0.
sub is-invariant-zero-text(Str $t --> Bool) is export {
    $t.starts-with('Invariant 0:') || $t.starts-with('Invariant 0.0:')
        || $t.starts-with('Invariant zero:')
}

#| The explicit number of a legacy invariant entry ('Invariant 3: ...'
#| gives '3'), or Str when the entry is unnumbered.
sub invariant-number(Str $t --> Str) is export {
    $t ~~ /^ 'Invariant ' (\d+) ':' / ?? ~$0 !! Str;
}

# --------------------------------------------------------------- grammar

#| The four blocks of the format, in canonical order.
constant @BLOCKS is export = 'IS FOR WHAT', 'IS FOR WHO', 'INVARIANT', 'BECAUSE';

#| Legacy placeholder gist written by the old 'iz4 init'.
constant GIST-PLACEHOLDER is export = '<What is this thing supposed to do?>';

#| Legacy sections, in their canonical order, with their kind.
constant %SECTION-KIND is export =
    gist        => 'text',
    behaviours  => 'list',
    invariants  => 'list',
    constraints => 'list',
    decisions   => 'list',
    direction   => 'list',
    references  => 'list';
constant @KNOWN-SECTIONS is export = <gist behaviours invariants constraints decisions direction references>;

#| Default indentation for legacy entries written by this tool.
constant INDENT is export = '    ';

#| Text written by this tool is wrapped at this width.
constant WRAP-WIDTH is export = 80;

#| Where content that is not enduring intent belongs instead.
constant ELSEWHERE is export =
    'requirements, plans, tasks and implementation detail belong in the '
    ~ 'README, ADRs, tests or issues';

class Problem {
    has Int  $.line    is required;
    has Str  $.message is required;
    has Bool $.warning = False;
    method Str(--> Str) { ($!warning ?? 'warning: ' !! '') ~ $!message }
}

#| One project invariant, in either dialect.
class Invariant {
    has Int $.number;                     # undefined when unnumbered
    has Str $.text    is required;
    has Str $.because;                    # undefined when none given
    has Int $.line    is required;        # its header (or legacy entry) line
    has Int $.because-line;
    has Int $.last-line is rw;            # last line of the INVARIANT block
}

#| A legacy list entry.
class Item {
    has Int $.line is required;
    has Str $.text is required;
}

#| A legacy section.
class Section {
    has Str  $.name is required;
    has Int  $.line is required;
    has Str  $.kind is required;
    has Int  $.last-line is rw;
    has Str  $.indent is rw;
    has Str  @.lines;
    has Item @.items;

    method text(--> Str)     { @!lines.join("\n") }
    method is-empty(--> Bool) { !@!lines && !@!items }
}

#| A block of the current format.
class Block {
    has Str $.kind is required;           # IS FOR WHAT | IS FOR WHO | INVARIANT | BECAUSE | other caps
    has Str $.label;                      # the text after INVARIANT, if any
    has Int $.line is required;
    has Int $.last-line is rw;
    has Str @.lines;
    method text(--> Str) { @!lines.join(' ').words.join(' ') }
}

has Str       $.source is required;
has IO::Path  $.path;
has Str       $.dialect;                  # 'iz4' | 'legacy'
has Str       $.version;                  # legacy trailing header version, read silently
has Str       $.for-what;
has Str       $.for-who;
has Int       $.for-what-line;
has Int       $.for-who-line;
has Invariant @.invariants;
has Block     @.blocks;
has Section   @.sections;
has Problem   @.problems;
has Str       @.lines;
has Int       $.header-line;

method load(IO::Path() $path --> IZ4::Document) {
    self.parse($path.slurp, :$path);
}

method parse(Str $source, IO::Path :$path --> IZ4::Document) {
    my $doc = self.bless(:$source, :$path);
    $doc!parse;
    $doc;
}

method errors   { @!problems.grep(!*.warning) }
method warnings { @!problems.grep(*.warning) }
method ok(--> Bool) { !self.errors }
method is-legacy(--> Bool) { $!dialect eq 'legacy' }

# legacy accessors, for tools that still read old files
method section(Str $name --> Section) { @!sections.first(*.name eq $name) }
method sections-named(Str $name)      { @!sections.grep(*.name eq $name) }

#| Project invariants with no number, in file order.
method unnumbered-invariants(--> List) { @!invariants.grep({ !.number.defined }).List }

#| Project invariants with no BECAUSE, in file order.
method unexplained-invariants(--> List) { @!invariants.grep({ !(.because // '').trim }).List }

#| Project invariants whose number falls in the inherited range 0-4
#| (only a legacy file can hold one; the current grammar refuses them).
method reserved-collisions(--> List) {
    @!invariants.grep({ .number.defined && .number < FIRST-PROJECT-NUMBER }).List
}

#| The next free project number: never below 5, never reusing one in use.
method next-number(--> Int) {
    my @used = @!invariants.map(*.number).grep(*.defined);
    max(FIRST-PROJECT-NUMBER, 1 + (-1, |@used).max);
}

#| One project invariant by number.
method invariant(Int $n) { @!invariants.first({ (.number // -1) == $n }) }

#| One line saying what this parse established about the foundation.
method foundation-status(--> Str) {
    my $digest = FOUNDATION-DIGEST.substr(0, 12);
    my $base = "Invariants 0-4: inherited from the foundation (sha256 $digest)";
    return $base unless self.is-legacy;
    with self!legacy-zero -> $zero {
        return squish-ws($zero.text) eq squish-ws(LEGACY-INVARIANT-ZERO)
            ?? "$base; the file repeats the earlier single Invariant 0 text, whose protections the foundation keeps"
            !! "$base; the file repeats a reworded earlier Invariant 0, and the foundation binds regardless";
    }
    $base;
}

#| True unless a legacy file repeats a reworded Invariant 0.
method foundation-intact(--> Bool) {
    return True unless self.is-legacy;
    my $zero = self!legacy-zero;
    !$zero.defined || squish-ws($zero.text) eq squish-ws(LEGACY-INVARIANT-ZERO);
}

method !legacy-zero {
    my $inv = self.section('invariants');
    $inv ?? $inv.items.first({ is-invariant-zero-text(.text) }) !! Nil;
}

#| Problems sorted by line, formatted as "NAME:LINE: message".
method report(Str :$name = ($!path ?? $!path.Str !! 'IZ4')) {
    @!problems.sort(*.line).map({ "$name:{.line}: {.Str}" });
}

method !problem(Int $line, Str $message, Bool :$warning = False) {
    @!problems.push: Problem.new(:$line, :$message, :$warning);
}

# ----------------------------------------------------------------- parse

method !parse() {
    @!lines = $!source.lines;
    my $header;
    for @!lines.kv -> $i, $raw {
        my $line = $raw.trim-trailing;
        next if $line eq '' || $line.starts-with('#');
        $header = $i;
        last;
    }
    without $header {
        self!problem(1, "expected 'IZ4' header (file is empty)");
        $!dialect = 'iz4';
        return;
    }
    my $first = @!lines[$header].trim-trailing;
    my $body-from = $header;
    if $first ~~ /^ ['IZ4' | 'SPOZ2'] [\s+ (\S+)]? $/ {
        $!version = ~$0 with $0;
        $!header-line = $header + 1;
        $body-from = $header + 1;
    }
    else {
        self!problem($header + 1, "expected 'IZ4' header on the first line");
    }

    # The dialect follows the first significant line after the header.
    my $legacy = False;
    for @!lines[$body-from .. *] -> $raw {
        my $line = $raw.trim-trailing;
        next if $line eq '' || $line.starts-with('#');
        $legacy = so $line ~~ /^ <[a..z]> <[\w\-]>* ':' $/;
        last;
    }
    $!dialect = $legacy ?? 'legacy' !! 'iz4';
    if $legacy { self!parse-legacy($body-from); self!validate-legacy }
    else       { self!parse-blocks($body-from); self!validate-blocks }
}

# ---------------------------------------------------------- current format

my regex caps-header { ^ <[A..Z]> <[A..Z 0..9 \x20]>* $ }

method !parse-blocks(Int $from) {
    my Block $current;
    for @!lines.kv -> $i, $raw {
        next if $i < $from;
        my $n    = $i + 1;
        my $line = $raw.trim-trailing;
        next if $line eq '';
        next if $line.starts-with('#');

        if $line ~~ /^ 'INVARIANT' [\s+ (.+)]? $/ {
            $current = Block.new(:kind<INVARIANT>, :label($0 ?? ~$0 !! Str), :line($n), :last-line($n));
            @!blocks.push: $current;
            next;
        }
        if $line ~~ &caps-header {
            if $line eq 'IZ4' {
                self!problem($n, "unexpected second 'IZ4' header");
                next;
            }
            $current = Block.new(:kind($line.words.join(' ')), :line($n), :last-line($n));
            @!blocks.push: $current;
            next;
        }
        without $current {
            self!problem($n, "text before any block: start with IS FOR WHAT");
            next;
        }
        $current.lines.push: $line.trim;
        $current.last-line = $n;
    }
}

method !validate-blocks() {
    my %seen;
    my Invariant $last-invariant;
    my Bool $last-was-invariant = False;
    my %numbers;

    for @!blocks -> $b {
        given $b.kind {
            when 'IS FOR WHAT' | 'IS FOR WHO' {
                my $kind = $b.kind;
                if %seen{$kind}:exists {
                    self!problem($b.line, "duplicate $kind (first at line {%seen{$kind}})");
                }
                else { %seen{$kind} = $b.line }
                self!problem($b.line, "$kind is empty") if $b.text eq '';
                if $kind eq 'IS FOR WHAT' { $!for-what = $b.text; $!for-what-line = $b.line }
                else                      { $!for-who  = $b.text; $!for-who-line  = $b.line }
                $last-was-invariant = False;
            }
            when 'INVARIANT' {
                my Int $number;
                with $b.label -> $label {
                    if $label ~~ /^ \d+ $/ {
                        $number = +$label;
                        if $number < FIRST-PROJECT-NUMBER {
                            self!problem($b.line,
                                "INVARIANT $number is reserved: Invariants 0-4 are inherited from the "
                                ~ "foundation and cannot be redefined; project invariants begin at "
                                ~ FIRST-PROJECT-NUMBER);
                        }
                        elsif %numbers{$number}:exists {
                            self!problem($b.line, "duplicate INVARIANT $number (first at line {%numbers{$number}})");
                        }
                        else { %numbers{$number} = $b.line }
                    }
                    else {
                        self!problem($b.line, "INVARIANT needs a whole number, like 'INVARIANT 5'");
                    }
                }
                else {
                    self!problem($b.line, "unnumbered INVARIANT ('iz4 number' numbers it)", :warning);
                }
                self!problem($b.line, ($number.defined ?? "INVARIANT $number" !! 'INVARIANT') ~ ' is empty') if $b.text eq '';
                $last-invariant = Invariant.new(:$number, :text($b.text), :line($b.line), :last-line($b.last-line));
                @!invariants.push: $last-invariant;
                $last-was-invariant = True;
            }
            when 'BECAUSE' {
                if $last-was-invariant && $last-invariant.defined {
                    self!problem($b.line, 'BECAUSE is empty') if $b.text eq '';
                    my $i = @!invariants.end;
                    @!invariants[$i] = Invariant.new(
                        :number($last-invariant.number), :text($last-invariant.text),
                        :because($b.text), :line($last-invariant.line),
                        :because-line($b.line), :last-line($last-invariant.last-line));
                }
                else {
                    self!problem($b.line, 'BECAUSE must directly follow the INVARIANT it explains');
                }
                $last-was-invariant = False;
            }
            default {
                self!problem($b.line,
                    "unknown block '$_' kept; IZ4 holds only IS FOR WHAT, IS FOR WHO, "
                    ~ "INVARIANT and BECAUSE - {ELSEWHERE}", :warning);
                $last-was-invariant = False;
            }
        }
    }

    my $end = @!lines.elems max 1;
    self!problem($end, 'missing IS FOR WHAT: what is this software for?')
        unless %seen{'IS FOR WHAT'}:exists;
    self!problem($end, 'missing IS FOR WHO: who is this software for?')
        unless %seen{'IS FOR WHO'}:exists;
}

# ------------------------------------------------------------ legacy format

method !parse-legacy(Int $from) {
    my Section $current;
    for @!lines.kv -> $i, $raw {
        next if $i < $from;
        my $n    = $i + 1;
        my $line = $raw.trim-trailing;

        next if $line eq '';
        next if $line.starts-with('#');

        if $line ~~ /^ (<[\w-]>+) ':' $/ {
            my $name = ~$0;
            if self.section($name) -> $dup {
                self!problem($n, "duplicate section '$name' (first defined at line {$dup.line})");
            }
            my $kind = %SECTION-KIND{$name} // 'unknown';
            $current = Section.new(:$name, :line($n), :$kind, :last-line($n));
            @!sections.push: $current;
            next;
        }

        if $line ~~ /^ \S/ {
            if $line ~~ /^ 'IZ4' \s/ {
                self!problem($n, "unexpected second 'IZ4' header");
            }
            else {
                self!problem($n, "unexpected text at column 0: '{$line.substr(0, 40)}' (section headers look like 'name:'; entries are indented)");
            }
            next;
        }

        without $current {
            self!problem($n, "entry before any section header");
            next;
        }

        $current.last-line = $n;
        my $indent  = $line.match(/^ \s+/).Str;
        my $content = $line.trim-leading;
        $current.indent //= $indent;

        if $current.kind eq 'text' {
            $current.lines.push: $content;
            next;
        }

        if $content ~~ /^ '-' [\s+ (.*)]? $/ {
            my $text = $0 ?? $0.Str.trim !! '';
            self!problem($n, "empty entry in section '{$current.name}'") if $text eq '';
            $current.items.push: Item.new(:line($n), :$text);
        }
        elsif $current.items {
            my $last = $current.items.pop;
            $current.items.push: Item.new(:line($last.line), :text($last.text ~ ' ' ~ $content));
        }
        elsif $current.kind eq 'list' {
            self!problem($n, "expected a '- ' entry in section '{$current.name}'");
        }
        else {
            $current.lines.push: $content;
        }
    }
}

method !validate-legacy() {
    self!problem($!header-line // 1,
        "legacy format, still read: IZ4 now holds only IS FOR WHAT, IS FOR WHO, "
        ~ "INVARIANT and BECAUSE ('iz4 migrate' converts it)", :warning);

    my @gists = self.sections-named('gist');
    if !@gists {
        self!problem(@!lines.elems max 1, "missing 'gist:' section");
    }
    else {
        my $gist = @gists[0];
        my $text = $gist.text.trim;
        if $text eq '' {
            self!problem($gist.line, "gist is empty");
        }
        elsif $text eq GIST-PLACEHOLDER {
            self!problem($gist.line, "gist is still the placeholder from 'iz4 init'");
        }
        else {
            $!for-what = $text.words.join(' ');
            $!for-what-line = $gist.line;
        }
    }

    for @!sections -> $s {
        next if %SECTION-KIND{$s.name}:exists;
        self!problem($s.line, "unknown section '{$s.name}'", :warning);
    }

    my $inv = self.section('invariants') // return;
    with self!legacy-zero -> $zero {
        if squish-ws($zero.text) ne squish-ws(LEGACY-INVARIANT-ZERO) {
            self!problem($zero.line,
                'Invariant 0 text differs from the earlier canonical wording '
                ~ '(the foundation, Invariants 0-4, binds regardless)', :warning);
        }
    }

    my %first-line;
    for $inv.items -> $item {
        next if is-invariant-zero-text($item.text);
        my $n    = invariant-number($item.text);
        my $text = $item.text.subst(/^ 'Invariant ' \d+ ':' \s*/, '');
        my ($claim, $because) = $text.split(/\s+ 'Because:' \s+/, 2);
        @!invariants.push: Invariant.new(
            :number($n.defined ?? +$n !! Int), :text($claim), :because($because // Str),
            :line($item.line), :last-line($item.line));
        without $n {
            self!problem($item.line, "unnumbered invariant ('iz4 number' gives every invariant a number)", :warning);
            next;
        }
        if %first-line{$n}:exists {
            self!problem($item.line, "duplicate invariant number '$n' (first used at line {%first-line{$n}})");
        }
        else { %first-line{$n} = $item.line }
        if +$n < FIRST-PROJECT-NUMBER {
            self!problem($item.line,
                "Invariant $n uses a number now reserved for the inherited foundation (0-4); "
                ~ "'iz4 migrate' renumbers project invariants from 5", :warning);
        }
    }
}

#| Whitespace-insensitive comparison for canonical text.
my sub squish-ws(Str $s --> Str) { $s.words.join(' ') }
