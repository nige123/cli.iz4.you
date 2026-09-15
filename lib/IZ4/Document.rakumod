unit class IZ4::Document;

#| The format is unversioned (user ruling, 2026-09-13: no 'IZ4 0.0' -
#| it is just Invariant 0, everywhere).  The header is the bare word
#| IZ4; legacy 'IZ4 <n>' headers are read silently.  The canonical
#| Invariant 0 below is one current text, identified by its digest and
#| evolving in Git like everything else; if release versioning is ever
#| needed, that will be a fresh decision.

#| Placeholder gist written by `iz4 init`.  `check` treats it as empty.
constant GIST-PLACEHOLDER is export = '<What is this thing supposed to do?>';

#| Invariant 0: every conforming IZ4 incorporates the canonical
#| Invariant 0, whether or not it repeats the text locally
#| (inheritance).  Omitting the text does not remove the obligation; no
#| entry may weaken or override it.  `init` seeds it; `check` verifies
#| any locally repeated text.  The digest identifies the adopted text,
#| nothing more: stating a rule, or hashing it, does not make software
#| obey it.
constant INVARIANT-ZERO is export =
    "Invariant 0: humans first. Help people thrive, and respect each person's "
    ~ 'dignity. Do no harm, and no greater good makes a person disposable. Keep '
    ~ 'humans in charge: explain consequential actions, accept challenge and '
    ~ 'correction, and stop safely when asked. When an objective conflicts with '
    ~ 'these protections, preserve them, report the conflict, and safely pause '
    ~ 'the affected action. Be honest about what this is, what it knows, what '
    ~ 'it has done, and what remains uncertain or blocked. No other entry may '
    ~ 'weaken this.';

#| sha256 of the exact one-line UTF-8 canonical text, no trailing newline.
constant INVARIANT-ZERO-DIGEST is export =
    '1af8b123edd8b27afba34c2ee385bb649c6eaed25647e7240f9f26cd440472f3';

#| The short teaching version, for pages and slides, never for files.
constant INVARIANT-ZERO-SHORT is export =
    'Help humans thrive. Keep humans in charge. Never fake it.';

#| The designations that identify Invariant 0, however the rest is
#| worded: 'Invariant 0:' now, plus the older 'Invariant 0.0:' and
#| 'Invariant zero:' spellings still found in existing files.
constant INVARIANT-ZERO-LEAD is export = 'Invariant 0:';
constant INVARIANT-ZERO-LEAD-DOTTED is export = 'Invariant 0.0:';
constant INVARIANT-ZERO-LEAD-LEGACY is export = 'Invariant zero:';
sub is-invariant-zero-text(Str $t --> Bool) is export {
    $t.starts-with(INVARIANT-ZERO-LEAD)
        || $t.starts-with(INVARIANT-ZERO-LEAD-DOTTED)
        || $t.starts-with(INVARIANT-ZERO-LEAD-LEGACY)
}

#| The explicit number of an invariant entry ('Invariant 3: ...' gives
#| '3'), or Str when the entry is unnumbered.  Numbers are plain
#| monotonic integers; 0 is the format's foundation invariant.
sub invariant-number(Str $t --> Str) is export {
    $t ~~ /^ 'Invariant ' (\d+) ':' / ?? ~$0 !! Str;
}

#| Known top-level sections, in canonical order, with their kind.
#| 'text' sections hold free text; 'list' sections hold "- " entries.
constant %SECTION-KIND is export =
    gist        => 'text',
    behaviours  => 'list',
    invariants  => 'list',
    constraints => 'list',
    decisions   => 'list',
    direction   => 'list',
    references  => 'list';

constant @KNOWN-SECTIONS is export = <gist behaviours invariants constraints decisions direction references>;

#| Singular nouns accepted by `iz4 add`, mapped to their section.
constant %NOUN-SECTION is export =
    gist       => 'gist',
    behaviour  => 'behaviours',
    invariant  => 'invariants',
    constraint => 'constraints',
    decision   => 'decisions',
    direction  => 'direction',
    reference  => 'references';

#| Default indentation for entries written by this tool.
constant INDENT is export = '    ';

#| Entries written by this tool are wrapped at this width.
constant WRAP-WIDTH is export = 80;

class Problem {
    has Int  $.line    is required;
    has Str  $.message is required;
    has Bool $.warning = False;
    method Str(--> Str) { ($!warning ?? 'warning: ' !! '') ~ $!message }
}

class Item {
    has Int $.line is required;
    has Str $.text is required;
}

class Section {
    has Str  $.name is required;
    has Int  $.line is required;          # line of the "name:" header
    has Str  $.kind is required;          # text | list | unknown
    has Int  $.last-line is rw;           # last content line (header if none)
    has Str  $.indent is rw;              # indent of first entry, if any
    has Str  @.lines;                     # raw text lines (text sections)
    has Item @.items;                     # entries (list sections)

    method text(--> Str)     { @!lines.join("\n") }
    method is-empty(--> Bool) { !@!lines && !@!items }
}

has Str      $.source is required;
has IO::Path $.path;
has Str      $.version;
has Section  @.sections;
has Problem  @.problems;
has Str      @.lines;                     # raw source lines, 1-based via [line-1]

method load(IO::Path() $path --> IZ4::Document) {
    self.parse($path.slurp, :$path);
}

method parse(Str $source, IO::Path :$path --> IZ4::Document) {
    my $doc = self.bless(:$source, :$path);
    $doc!parse-lines;
    $doc!validate;
    $doc;
}

method section(Str $name --> Section) { @!sections.first(*.name eq $name) }
method sections-named(Str $name)      { @!sections.grep(*.name eq $name) }
method errors   { @!problems.grep(!*.warning) }
method warnings { @!problems.grep(*.warning) }
method ok(--> Bool) { !self.errors }

#| One line describing what this parse established about Invariant 0.
#| `iz4 check` prints it, so a successful check says what was verified
#| and never implies more.
method invariant-zero-status(--> Str) {
    my $digest = INVARIANT-ZERO-DIGEST.substr(0, 12);
    my $inv    = self.section('invariants');
    my $zero   = $inv ?? $inv.items.first({ is-invariant-zero-text(.text) }) !! Nil;
    with $zero {
        return squish-ws(.text) eq squish-ws(INVARIANT-ZERO)
            ?? "Invariant 0: repeated locally, matches the canonical text (sha256 $digest)"
            !! "Invariant 0: repeated locally but differs from the canonical text (sha256 $digest binds regardless)";
    }
    "Invariant 0: not repeated locally, still binding (canonical sha256 $digest)";
}

#| Problems sorted by line, formatted as "NAME:LINE: message".
method report(Str :$name = ($!path ?? $!path.Str !! 'IZ4')) {
    @!problems.sort(*.line).map({ "$name:{.line}: {.Str}" });
}

method !problem(Int $line, Str $message, Bool :$warning = False) {
    @!problems.push: Problem.new(:$line, :$message, :$warning);
}

method !parse-lines() {
    @!lines = $!source.lines;
    my Bool $header-seen = False;
    my Section $current;

    for @!lines.kv -> $i, $raw {
        my $n    = $i + 1;
        my $line = $raw.trim-trailing;

        next if $line eq '';                 # blank
        next if $line.starts-with('#');      # full-line comment at column 0

        if !$header-seen {
            $header-seen = True;
            # Bare 'IZ4' is the header; the legacy 'SPOZ2' word and a
            # legacy trailing version are read silently and mean nothing.
            if $line ~~ /^ ['IZ4' | 'SPOZ2'] [\s+ (\S+)]? $/ {
                $!version = ~$0 with $0;
                next;
            }
            self!problem($n, "expected 'IZ4' header on the first line");
            # fall through and treat this line normally
        }

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

        # An indented line: content belonging to the current section.
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
            # continuation of the previous entry
            my $last = $current.items.pop;
            $current.items.push: Item.new(:line($last.line), :text($last.text ~ ' ' ~ $content));
        }
        elsif $current.kind eq 'list' {
            self!problem($n, "expected a '- ' entry in section '{$current.name}'");
        }
        else {
            # unknown section with free text: keep it as text
            $current.lines.push: $content;
        }
    }

    unless $header-seen {
        self!problem(1, "expected 'IZ4' header (file is empty)");
    }
}

method !validate() {
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
    }

    for @!sections -> $s {
        next if %SECTION-KIND{$s.name}:exists;
        self!problem($s.line, "unknown section '{$s.name}'", :warning);
    }

    # Invariant 0 binds whether or not the file repeats it.  A repeated
    # copy is verified; omission is legitimate.  Warnings, never errors.
    my $inv   = self.section('invariants');
    my $first = $inv ?? $inv.items.head !! Nil;
    my $zero  = $inv ?? $inv.items.first({ is-invariant-zero-text(.text) }) !! Nil;
    if $zero.defined {
        unless $first.defined && is-invariant-zero-text($first.text) {
            self!problem($zero.line,
                "Invariant 0 ('humans first') should be the first invariant", :warning);
        }
        if squish-ws($zero.text) ne squish-ws(INVARIANT-ZERO) {
            self!problem($zero.line,
                "Invariant 0 text differs from the canonical wording (the canonical text binds regardless)",
                :warning);
        }
    }

    # Numbered invariants are references; a duplicate number defeats the
    # reference, so it is an error.  Unnumbered entries stay valid.
    if $inv.defined {
        my %first-line;
        for $inv.items -> $item {
            my $n = invariant-number($item.text);
            next without $n;
            with %first-line{$n} -> $at {
                self!problem($item.line, "duplicate invariant number '$n' (first used at line $at)");
            }
            else { %first-line{$n} = $item.line }
        }
    }
}

#| Whitespace-insensitive comparison for canonical text (entries are
#| wrapped and rejoined; spacing must not defeat the match).
my sub squish-ws(Str $s --> Str) { $s.words.join(' ') }
