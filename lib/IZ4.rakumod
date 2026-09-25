unit module IZ4;

use IZ4::Document;
use IZ4::Git;
use IZ4::Coach;

constant VERSION is export = '0.2.0';

#| A user-facing error: message only, no stack trace.
class X::IZ4 is Exception {
    has Str $.message is required;
}
sub user-error(Str $message) { X::IZ4.new(:$message).throw }

constant ROOT-NAME is export = 'IZ4';

#| The legacy root name: read silently, never written.
constant LEGACY-ROOT-NAME is export = 'SPOZ2';

#| sha256 of a file's exact bytes, via whichever digest tool this system
#| has - sha256sum (Linux), shasum (macOS/BSD) or openssl - external,
#| like Git, so the CLI works across operating systems and architectures.
sub sha256-file(IO::Path $f --> Str) is export {
    for ('sha256sum',), ('shasum', '-a', '256'), ('openssl', 'dgst', '-sha256', '-r') -> @tool {
        my $hex = try {
            my $p = run |@tool.map(*.Str), $f.Str, :out, :err;
            my $o = $p.out.slurp(:close);
            $p.err.slurp(:close);
            $p.exitcode == 0 ?? $o.words.head !! Nil;
        };
        return $hex.lc if $hex.defined && $hex ~~ /^ <[0..9 A..F a..f]> ** 64 $/;
    }
    user-error('no sha256 tool found (need sha256sum, shasum or openssl)');
}

# ---------------------------------------------------------------- discovery

#| Walk upward from $start looking for a root IZ4 file.
sub find-root(IO::Path $start = $*CWD --> IO::Path) is export {
    my $dir = $start.resolve;
    loop {
        for ROOT-NAME, LEGACY-ROOT-NAME -> $name {
            my $candidate = $dir.add($name);
            return $candidate if $candidate.f;
        }
        my $parent = $dir.parent;
        return Nil if $parent eq $dir;
        $dir = $parent;
    }
}

#| True when a CLI argument names a IZ4 document rather than a section or revision.
sub looks-like-file(Str $arg --> Bool) is export {
    so $arg.ends-with('.iz4') || $arg.ends-with('.spoz2')
        || $arg.IO.basename eq ROOT-NAME | LEGACY-ROOT-NAME;
}

#| The document to operate on: an explicit path, or the nearest root IZ4.
sub resolve-target(Str $file?, IO::Path :$cwd = $*CWD --> IO::Path) is export {
    with $file {
        my $path = $file.IO.is-absolute ?? $file.IO !! $cwd.add($file);
        user-error("$file: no such file") unless $path.f;
        return $path;
    }
    find-root($cwd) // user-error(
        "No IZ4 found in this directory or its parents.\nRun 'iz4 init' to create one.");
}

#| How a path is shown in messages: relative to the working directory.
sub display-name(IO::Path $path, IO::Path :$cwd = $*CWD --> Str) is export {
    my $rel = $path.resolve.relative($cwd.resolve);
    $rel.starts-with('../../..') ?? $path.resolve.Str !! $rel;
}

# ---------------------------------------------------------------- teaching

#| The line every new IZ4 carries, so a reader knows 0-4 exist.
constant INHERITANCE-COMMENT is export =
    "# Every IZ4 inherits Invariants 0-4 ('iz4 invariants' shows them).\n"
    ~ '# Project invariants begin at 5.';

#| Paired examples: what does and does not belong.  The right-hand side
#| is not automatically an invariant either; the owner decides.
constant EXAMPLES is export = q:to/END/;
    NOT IZ4                      IZ4
    Uses PostgreSQL              Private data is permanently deleted when
                                 an account is deleted.
    Uses WebAuthn                A person proves control before private
                                 information is revealed.
    Shows 20 results             Private profiles never appear in public
                                 search.
    Uses SSR                     Core journeys work without client-side
                                 JavaScript. (only if that is genuinely
                                 enduring product intent)

    The right-hand column is not automatically an invariant either: the
    project owner decides what must remain true.
    END

# ---------------------------------------------------------------- init

#| A new IZ4: the two answers that are its heart, and nothing else.
sub template(Str :$for-what!, Str :$for-who! --> Str) is export {
    join "\n",
        ROOT-NAME, '',
        INHERITANCE-COMMENT, '',
        'IS FOR WHAT?', |wrap($for-what.trim, WRAP-WIDTH), '',
        'IS FOR WHO?', |wrap($for-who.trim, WRAP-WIDTH), '';
}

#| Create a root IZ4 in $dir.  Refuses to overwrite; refuses empty answers.
sub init(IO::Path :$dir = $*CWD, Str :$for-what!, Str :$for-who! --> IO::Path) is export {
    my $path = $dir.add(ROOT-NAME);
    user-error("{ROOT-NAME} already exists here; not overwriting") if $path.e;
    user-error("a legacy {LEGACY-ROOT-NAME} already exists here; rename it to {ROOT-NAME} (git mv {LEGACY-ROOT-NAME} {ROOT-NAME}) and run 'iz4 migrate'")
        if $dir.add(LEGACY-ROOT-NAME).e;
    user-error('what is this for? the answer cannot be empty') if $for-what.trim eq '';
    user-error('who is this for? the answer cannot be empty')  if $for-who.trim eq '';
    $path.spurt(template(:$for-what, :$for-who));
    $path;
}

# ---------------------------------------------------------------- show

#| Text of the whole document, or of one part: 'for-what', 'for-who' or
#| 'invariants' (legacy files also answer to their old section names).
sub show-text(IO::Path $path, Str $part? is copy --> Str) is export {
    my $doc = IZ4::Document.load($path);
    without $part { return $doc.source }
    $part = $part.lc;
    given $part {
        when 'for-what' | 'what' | 'is-for-what' {
            return ($doc.for-what // user-error("no IS FOR WHAT in {$path.basename}")) ~ "\n";
        }
        when 'for-who' | 'who' | 'is-for-who' {
            return ($doc.for-who // user-error("no IS FOR WHO in {$path.basename}")) ~ "\n";
        }
        when 'invariants' | 'invariant' {
            return project-invariants-text($doc);
        }
    }
    user-error("unknown part '$part'; use for-what, for-who or invariants") unless $doc.is-legacy;
    my @found = $doc.sections-named($part eq 'behaviour' ?? 'behaviours' !! $part);
    user-error("no section '$part' in {$path.basename}") unless @found;
    my @out;
    for @found -> $s {
        my @body = $doc.lines[$s.line .. $s.last-line - 1];
        my $indent = $s.indent // '';
        @out.append: @body.map({ .starts-with($indent) ?? .substr($indent.chars) !! .trim-leading });
    }
    @out.join("\n") ~ "\n";
}

#| One invariant as a reader sees it: header, text, BECAUSE.
sub invariant-block(Int $number, Str $name, Str $text, Str $because?, Str :$note --> Str) {
    my @out = ("INVARIANT $number" ~ ($name ?? " - $name" !! '') ~ ($note ?? " ($note)" !! ''));
    @out.append: wrap($text, WRAP-WIDTH);
    if $because.defined && $because.trim {
        @out.push: 'BECAUSE';
        @out.append: wrap($because, WRAP-WIDTH);
    }
    @out.join("\n") ~ "\n";
}

sub project-invariants-text(IZ4::Document $doc --> Str) {
    return "(no project invariants yet: 'iz4 add' helps you find one)\n" unless $doc.invariants;
    $doc.invariants.map({
        .number.defined
            ?? invariant-block(.number, Str, .text, .because)
            !! "INVARIANT (unnumbered)\n" ~ wrap(.text, WRAP-WIDTH).join("\n") ~ "\n"
    }).join("\n");
}

#| The effective invariant set: the inherited foundation, then the
#| project's own.  This is what a person or agent should read before a
#| consequential change.
sub effective-text(IZ4::Document $doc, Str :$name = 'IZ4' --> Str) is export {
    my @out;
    @out.push: "IS FOR WHAT?\n" ~ wrap($doc.for-what // '(not stated)', WRAP-WIDTH).join("\n") ~ "\n";
    @out.push: "IS FOR WHO?\n"  ~ wrap($doc.for-who  // '(not stated)', WRAP-WIDTH).join("\n") ~ "\n";
    @out.append: FOUNDATION.map({ invariant-block(.<number>, .<name>, .<text>, .<because>, :note<inherited>) });
    @out.push: project-invariants-text($doc);
    my $collisions = $doc.reserved-collisions;
    if $collisions {
        @out.push: "note: $name is in the legacy format and numbers "
            ~ "{$collisions».number.sort.join(', ')} of its own invariants inside the "
            ~ "inherited range 0-4; 'iz4 migrate' renumbers them from 5\n";
    }
    @out.join("\n");
}

#| One invariant by number (5, 'Invariant 5' and '5:' all work).  0-4
#| always name the foundation.
sub invariant-text(IO::Path $path, Str $number --> Str) is export {
    my $doc = IZ4::Document.load($path);
    my $raw = $number.subst(/:i^ 'invariant' \s+ /, '').subst(/ ':' $/, '');
    user-error("'$number' is not an invariant number") unless $raw ~~ /^ \d+ $/;
    my $n = +$raw;
    if $n < FIRST-PROJECT-NUMBER {
        my %f = FOUNDATION[$n];
        my $text = invariant-block($n, %f<name>, %f<text>, %f<because>, :note<inherited>);
        with $doc.invariant($n) {
            $text ~= "note: {$path.basename} also numbers one of its own invariants $n "
                ~ "(legacy format); 'iz4 migrate' renumbers it from 5\n";
        }
        return $text;
    }
    with $doc.invariant($n) {
        return invariant-block($n, Str, .text, .because);
    }
    my @nums = $doc.invariants.map(*.number).grep(*.defined);
    user-error("no invariant $n in {$path.basename}; "
        ~ (@nums ?? "its own are {@nums.join(', ')}, and 0-4 are inherited"
                 !! "it has none of its own yet, and 0-4 are inherited"));
}

# ---------------------------------------------------------------- check

#| Parse and validate.  Returns the Document; caller inspects .problems.
sub check-doc(IO::Path $path --> IZ4::Document) is export {
    IZ4::Document.load($path);
}

# ---------------------------------------------------------------- add

#| Why a kind the old format accepted no longer has a place in IZ4.
constant %ELSEWHERE-FOR is export =
    behaviour  => "IZ4 does not record behaviours: describe them in the README or pin them with tests. If one must survive any rewrite, add it as an invariant.",
    constraint => "IZ4 does not record constraints: implementation limits belong in the README or an ADR. If one protects something that must remain true, add that as an invariant.",
    decision   => "IZ4 does not record decisions: they belong in ADRs and commit messages.",
    direction  => "IZ4 does not record plans: they belong in your issues or roadmap.",
    reference  => "IZ4 does not record references: link standards from the README.",
    requirement => "IZ4 does not record requirements: they belong in issues, a spec tool or tests. If one must survive any rewrite, add it as an invariant.",
    task       => "IZ4 does not record tasks: track them in your issues.";

#| Set IS FOR WHAT or IS FOR WHO.  An existing answer needs :replace.
sub set-is-for(IO::Path $path, Str $which where 'IS FOR WHAT' | 'IS FOR WHO', Str $text,
               Bool :$replace = False --> Str) is export {
    my $value = $text.trim;
    user-error("nothing to set: the answer is empty") if $value eq '';
    my $doc   = IZ4::Document.load($path);
    my @lines = $doc.lines;

    if $doc.is-legacy {
        user-error("{$path.basename} is in the legacy format, which has no IS FOR WHO; run 'iz4 migrate'")
            if $which eq 'IS FOR WHO';
        return set-legacy-gist($path, $doc, $value, :$replace);
    }

    my @new = wrap($value, WRAP-WIDTH);
    with $doc.blocks.first(*.kind eq $which) -> $b {
        user-error("$which is already set; use --replace to replace it")
            if $b.text ne '' && !$replace;
        @lines.splice($b.line, $b.last-line - $b.line, @new);
        @lines[$b.line - 1] = "$which?";           # asked as a question
    }
    else {
        my $after = do if $which eq 'IS FOR WHO' {
            $doc.blocks.first(*.kind eq 'IS FOR WHAT') andthen .last-line
        } // ($doc.header-line // 0);
        @lines.splice($after, 0, '', "$which?", |@new);
    }
    $path.spurt(@lines.join("\n") ~ "\n");
    $which;
}

sub set-legacy-gist(IO::Path $path, IZ4::Document $doc, Str $value, Bool :$replace --> Str) {
    my @lines = $doc.lines;
    my $s = $doc.section('gist');
    my @new = wrap($value, WRAP-WIDTH - INDENT.chars).map({ INDENT ~ $_ });
    with $s {
        my $text = $s.text.trim;
        user-error("IS FOR WHAT (the legacy gist) is already set; use --replace to replace it")
            if $text ne '' && $text ne GIST-PLACEHOLDER && !$replace;
        @lines.splice($s.line, $s.last-line - $s.line, @new);
    }
    else {
        @lines.splice($doc.header-line // 0, 0, '', 'gist:', |@new);
    }
    $path.spurt(@lines.join("\n") ~ "\n");
    'IS FOR WHAT';
}

#| Add a project invariant, with its BECAUSE when given.  It takes the
#| next free number from 5 unless :$number chooses one; 0-4 and numbers in
#| use are refused.  Returns the number written.  Existing text is never
#| touched: the new block is appended.
sub add-invariant(IO::Path $path, Str $text, Str :$because, Int :$number --> Int) is export {
    my $value = $text.trim;
    user-error("nothing to add: the invariant is empty") if $value eq '';
    my $doc = IZ4::Document.load($path);

    # an explicit 'Invariant 7: ...' lead is a chosen number
    my Int $n = $number;
    if $value ~~ /:i^ 'invariant' \s+ (\d+) \s* <[:.\-]>? \s+ (.+) $/ {
        $n //= +$0;
        $value = ~$1;
    }
    with $n {
        user-error("Invariant $n is inherited and reserved: Invariants 0-4 cannot be redefined; "
            ~ "project invariants begin at {FIRST-PROJECT-NUMBER}") if $n < FIRST-PROJECT-NUMBER;
        user-error("Invariant $n is already used in {$path.basename}; pick a free number")
            if $doc.invariant($n).defined;
    }
    else { $n = $doc.next-number }
    my $reason = ($because // '').trim;

    my @lines = $doc.lines;
    @lines.pop while @lines && @lines[*-1].trim eq '';
    if $doc.is-legacy {
        my $entry = "Invariant $n: $value" ~ ($reason ne '' ?? " Because: $reason" !! '');
        my $inv = $doc.section('invariants');
        my @new = legacy-entry-lines($entry, $inv ?? ($inv.indent // INDENT) !! INDENT);
        with $inv { @lines.splice($inv.last-line, 0, @new) }
        else      { @lines.append: '', 'invariants:', |@new }
    }
    else {
        @lines.append: '', "INVARIANT $n", |wrap($value, WRAP-WIDTH);
        @lines.append: '', 'BECAUSE', |wrap($reason, WRAP-WIDTH) if $reason ne '';
    }
    $path.spurt(@lines.join("\n") ~ "\n");
    $n;
}

# ---------------------------------------------------------------- because

#| Set the BECAUSE of project invariant $n.  An existing one needs
#| :replace.  Only the current format has a BECAUSE block; a legacy file
#| is told to migrate.  Returns the number.
sub set-because(IO::Path $path, Int $n, Str $text, Bool :$replace = False --> Int) is export {
    my $reason = $text.trim;
    user-error('nothing to set: the reason is empty') if $reason eq '';
    my $doc = IZ4::Document.load($path);
    user-error("{$path.basename} is in the legacy format; run 'iz4 migrate' first") if $doc.is-legacy;
    my $inv = invariant-or-die($doc, $path, $n);
    user-error("Invariant $n already has a BECAUSE; use --replace to replace it")
        if ($inv.because // '').trim && !$replace;
    rewrite-invariant($path, $doc, $inv, $inv.text, $reason);
    $n;
}

#| Move the reason folded into invariant $n's own text under BECAUSE.
#| Returns the reason moved, or Str when none was found.  The words are
#| the owner's, only moved; nothing is added.
sub split-because(IO::Path $path, Int $n --> Str) is export {
    my $doc = IZ4::Document.load($path);
    user-error("{$path.basename} is in the legacy format; run 'iz4 migrate' first") if $doc.is-legacy;
    my $inv = invariant-or-die($doc, $path, $n);
    user-error("Invariant $n already has a BECAUSE") if ($inv.because // '').trim;
    my ($claim, $reason) = split-reason($inv.text);
    return Str without $reason;
    rewrite-invariant($path, $doc, $inv, $claim, $reason);
    $reason;
}

#| Every invariant without a BECAUSE whose text holds one: split them all.
#| Returns (number, reason) pairs.
sub split-all-because(IO::Path $path --> List) is export {
    my @done;
    for IZ4::Document.load($path).unexplained-invariants.map(*.number).grep(*.defined) -> $n {
        with split-because($path, $n) -> $reason { @done.push: ($n, $reason) }
    }
    @done;
}

sub invariant-or-die(IZ4::Document $doc, IO::Path $path, Int $n) {
    user-error("Invariant $n is inherited; the foundation's reasons are canonical") if $n < FIRST-PROJECT-NUMBER;
    $doc.invariant($n) // user-error("no invariant $n in {$path.basename}");
}

#| Replace one INVARIANT block (and its BECAUSE, if any) with new wrapped
#| text and reason.  Everything outside the block is untouched.
sub rewrite-invariant(IO::Path $path, IZ4::Document $doc, $inv, Str $claim, Str $reason) {
    my @lines = $doc.lines;
    my $from  = $inv.line - 1;
    my $to    = ($inv.because-line.defined
        ?? ($doc.blocks.first({ .kind eq 'BECAUSE' && .line == $inv.because-line }).last-line)
        !! $inv.last-line) - 1;
    my @new = "INVARIANT {$inv.number}", |wrap($claim, WRAP-WIDTH);
    @new.append: '', 'BECAUSE', |wrap($reason, WRAP-WIDTH) if $reason.trim;
    @lines.splice($from, $to - $from + 1, @new);
    $path.spurt(@lines.join("\n") ~ "\n");
}

#| Lines for one legacy '- ' entry, wrapped to WRAP-WIDTH.
sub legacy-entry-lines(Str $value, Str $indent) {
    my @out;
    for wrap($value, WRAP-WIDTH - $indent.chars - 2) -> $line {
        @out.push: (@out ?? $indent ~ '  ' !! $indent ~ '- ') ~ $line;
    }
    @out;
}

#| Greedy word wrap; a single over-long word stays on its own line.
sub wrap(Str $text, Int $width) is export {
    my @lines;
    my $line = '';
    for $text.words -> $word {
        if $line eq '' { $line = $word }
        elsif $line.chars + 1 + $word.chars <= $width { $line ~= ' ' ~ $word }
        else { @lines.push($line); $line = $word }
    }
    @lines.push($line) if $line ne '';
    @lines || ('',);
}

# ---------------------------------------------------------------- number

#| Give every unnumbered invariant in $path the next free number from 5,
#| in file order.  Existing numbers are references and are never changed;
#| only the header (or legacy first line) of each one numbered is
#| touched.  Returns (line, number) pairs, empty when there was nothing
#| to do.
sub number-invariants(IO::Path $path --> List) is export {
    my @lines = IZ4::Document.load($path).lines;
    my @done  = number-lines(@lines);
    $path.spurt(@lines.join("\n") ~ "\n") if @done;
    @done;
}

#| The same, on a whole IZ4 held as @lines, changed in place.
sub number-lines(@lines --> List) is export {
    my $doc  = IZ4::Document.parse(@lines.join("\n") ~ "\n");
    my @todo = $doc.unnumbered-invariants;
    return () unless @todo;
    my $next = $doc.next-number;
    my @done;
    for @todo -> $inv {
        my $i = $inv.line - 1;
        if $doc.is-legacy {
            @lines[$i] = @lines[$i].subst(/^ (\s* '-') \s*/, { "$0 Invariant $next: " });
        }
        else {
            @lines[$i] = "INVARIANT $next";
        }
        @done.push: ($inv.line, $next++);
    }
    @done;
}

# ---------------------------------------------------------------- migrate

#| Convert a legacy IZ4 to the current format.  Returns a hash with the
#| new 'text', the 'companion' Markdown holding everything the new format
#| does not keep (word for word, so nothing is silently discarded), and
#| the invariant number 'mapping' as (old, new) pairs.  Writes nothing:
#| the caller decides.
sub migrate-text(IO::Path $path, Str :$for-who! --> Hash) is export {
    my $doc = IZ4::Document.load($path);
    user-error("{$path.basename} is already in the current format") unless $doc.is-legacy;
    user-error("fix the errors 'iz4 check' reports before migrating") if $doc.errors;
    user-error('who is this for? the answer cannot be empty') if $for-who.trim eq '';
    my $name = $path.basename;

    # Renumber once, only when a project number sits in 0-4: shift every
    # number up by the same amount so relative order and gaps survive.
    my @numbered = $doc.invariants.grep(*.number.defined);
    my $lowest = @numbered ?? @numbered».number.min !! FIRST-PROJECT-NUMBER;
    my $shift  = max(0, FIRST-PROJECT-NUMBER - $lowest);
    my @mapping;
    my $next = max(FIRST-PROJECT-NUMBER, 1 + (@numbered ?? @numbered».number.max + $shift !! FIRST-PROJECT-NUMBER - 1));

    my @out = ROOT-NAME, '', INHERITANCE-COMMENT, '',
        'IS FOR WHAT?', |wrap($doc.for-what // '', WRAP-WIDTH), '',
        'IS FOR WHO?', |wrap($for-who.trim, WRAP-WIDTH);
    my @placed;
    for $doc.invariants -> $inv {
        my $new = $inv.number.defined ?? $inv.number + $shift !! $next++;
        @mapping.push: ($inv.number, $new);
        @placed.push: ($new, $inv);
    }
    # written in number order, so the file reads 5, 6, 7 ...  The old
    # format had no BECAUSE, so authors folded the why into the entry;
    # a reason the detector can see is moved under BECAUSE and reported.
    my @split;
    for @placed.sort(*.[0]) -> ($new, $inv) {
        my ($claim, $reason) = $inv.text, $inv.because;
        unless ($reason // '').trim {
            ($claim, $reason) = split-reason($inv.text);
            @split.push: ($new, $reason) with $reason;
        }
        @out.append: '', "INVARIANT $new", |wrap($claim, WRAP-WIDTH);
        @out.append: '', 'BECAUSE', |wrap($reason, WRAP-WIDTH) if ($reason // '').trim;
    }
    @mapping = @mapping.sort({ $_[0] // Inf });
    my $text = @out.join("\n") ~ "\n";

    # everything else, word for word
    my @c = "# $name before migration", '',
        "`iz4 migrate` converted $name to the Is For format on {Date.today}. The new",
        'file keeps only what the system is for, who it is for, and the',
        'invariants that must remain true. Everything else it held is kept here',
        'word for word, so nothing was lost. Move each part to wherever it now',
        'belongs - the README, an ADR, tests or issues - or delete what no',
        'longer matters.', '';
    @c.append: '## Invariant numbers', '';
    if $shift {
        @c.append: 'Invariants 0-4 are now the inherited foundation, so project invariants',
            "were renumbered by adding $shift:", '',
            '| before | after |', '|---|---|',
            |@mapping.map({ "| {.[0] // 'unnumbered'} | {.[1]} |" }), '';
    }
    else {
        @c.append: 'Numbered invariants kept their numbers'
            ~ (@mapping.grep({ !.[0].defined }) ?? '; unnumbered ones were numbered from ' ~ ($next - @mapping.grep({ !.[0].defined }).elems) !! '')
            ~ '.', '';
    }
    if @split {
        @c.append: '## Reasons moved under BECAUSE', '',
            'These invariants ended with a sentence that read as the reason, so it was',
            'moved under BECAUSE. Check each: the words are unchanged, only moved.', '',
            |@split.map({ "- Invariant {.[0]}: {.[1]}" }), '';
    }
    for $doc.sections -> $s {
        next if $s.name eq 'invariants';
        @c.append: "## {$s.name}", '';
        if $s.kind eq 'list' {
            @c.append: $s.items.map({ "- {.text}" });
        }
        else {
            @c.append: $s.lines;
        }
        @c.push: '';
    }
    with $doc.sections.first(*.name eq 'invariants') -> $inv {
        with $inv.items.first({ is-invariant-zero-text(.text) }) -> $zero {
            unless $doc.foundation-intact {
                @c.append: '## Invariant 0 as this file worded it', '',
                    'The foundation, Invariants 0-4, binds regardless of this wording; any',
                    'protection here that goes beyond it belongs in a project invariant.', '',
                    $zero.text, '';
            }
        }
    }
    my @comments = $doc.lines.grep({ .starts-with('#') });
    if @comments {
        @c.append: '## Comments', '', |@comments.map({ "    $_" }), '';
    }
    %( :$text, companion => @c.join("\n"), :@mapping, :@split, renumbered => ?$shift );
}

# ---------------------------------------------------------------- suggest

#| The agent command behind `iz4 suggest`: overridable, external, optional.
sub agent-cmd(--> Str) is export { %*ENV<IZ4_AGENT_CMD> // %*ENV<SPOZ2_AGENT_CMD> // 'claude -p' }

#| The prompt for repository analysis.  Its job is to keep IZ4 small.
sub suggest-prompt(Str :$current = '', Str :$evidence = '' --> Str) is export {
    q:to/END/ ~ ($current.trim || '(none yet)') ~ "\n\nEvidence from the codebase:\n" ~ $evidence ~ "\n";
    You are helping a developer find the few enduring invariants of the
    system in this repository, for its IZ4 file.

    IZ4 means Is For.  An IZ4 answers three questions: what is this system
    for, who is it for, and what must remain true for it to keep serving
    them.  It is deliberately incomplete.

    Do not try to make IZ4 complete.  Try to make it small.

    Every IZ4 inherits Invariants 0-4 (humans first, do no harm, human
    agency, honesty, the foundation holds).  Do not restate them; propose
    only this project's own invariants.

    The golden test: if the whole system were rewritten tomorrow,
    would we regret not telling the people and agents rebuilding it this?
    If yes: does it describe enduring intent rather than today's
    implementation?  If yes: how does it matter to what the system is
    for, who it is for, or the inherited foundation?  Only a meaningful
    answer to all three makes a strong candidate.

    - An observed behaviour is not automatically an invariant.
    - Tests passing today do not prove something belongs in IZ4.
    - Repeated implementation patterns do not prove something belongs in IZ4.
    - Framework, language, database and library choices do not normally
      belong in IZ4.
    - Requirements, settings, plans, tasks and acceptance criteria do not
      belong in IZ4.
    - When the distinction depends on product intent the repository cannot
      show, classify it POSSIBLE and write the question to ask the owner.
      Never invent intent.
    - Propose at most 3 STRONG and at most 4 POSSIBLE.  Fewer, stronger
      invariants are better than apparent completeness.  None is an
      acceptable answer.
    - For IMPLEMENTATION and NOT IZ4 give at most 3 of the most tempting
      examples, so the developer sees why they were left out.

    Reply with one item per line and nothing else, in exactly this form:
    STRONG | what must remain true, in one sentence | BECAUSE: why it must survive | evidence
    POSSIBLE | the candidate | the question only the owner can answer
    IMPLEMENTATION | what you observed | where it belongs instead
    NOT IZ4 | what you observed | where it belongs instead

    The current IZ4:
    END
}

#| Read the agent's classified reply.  Unknown lines are ignored; strong
#| and possible candidates are capped so a flood never reaches the person.
sub parse-suggestions(Str $reply, Int :$cap = 5 --> Hash) is export {
    my %s = strong => [], possible => [], implementation => [], not-iz4 => [];
    for $reply.lines -> $raw {
        my $line = $raw.trim.subst(/^ <[\-*•]> \s* /, '');
        my @f = $line.split(/\s* '|' \s*/)».trim;
        next unless @f >= 2 && @f[1] ne '';
        my $label = @f[0].uc.subst(/<[\-_]>/, ' ', :g).words.join(' ');
        given $label {
            when 'STRONG' {
                %s<strong>.push: %( text => @f[1],
                    because => (@f[2] // '').subst(/:i^ 'because' ':'? \s* /, ''),
                    evidence => @f[3] // '' );
            }
            when 'POSSIBLE'       { %s<possible>.push: %( text => @f[1], question => @f[2] // '' ) }
            when 'IMPLEMENTATION' { %s<implementation>.push: %( text => @f[1], belongs => @f[2] // '' ) }
            when 'NOT IZ4' | 'DOES NOT BELONG' | 'NOT IN IZ4' {
                %s<not-iz4>.push: %( text => @f[1], belongs => @f[2] // '' );
            }
        }
    }
    %s<found> = %( strong => +%s<strong>, possible => +%s<possible> );
    %s<strong>   = [%s<strong>.head($cap)];
    %s<possible> = [%s<possible>.head($cap)];
    %s;
}

#| One agent pass over the repository.  Dies when the agent fails; a
#| reply with no usable lines is an honest 'nothing found'.
sub agent-suggest(IO::Path $dir = $*CWD, Str :$cmd = agent-cmd(), Str :$current = '' --> Hash) is export {
    my $prompt = suggest-prompt(:$current, evidence => gather-context($dir));
    note "asking agent ($cmd) for candidate invariants in {$dir.resolve} ...";
    my $proc = run '/bin/sh', '-c', $cmd, :in, :out;
    $proc.in.print($prompt);
    my $ = $proc.in.close;
    my $reply = $proc.out.slurp(:close);
    die "agent command failed ($cmd)" if $proc.exitcode != 0;
    parse-suggestions($reply);
}

#| Bounded evidence for the agent: the codebase's own account of itself
#| (README, changelog, file layout), never the whole tree.
sub gather-context(IO::Path $dir --> Str) is export {
    my @parts;
    for <README.md README.txt README>, <CHANGES.md CHANGELOG.md Changes> -> @names {
        for @names -> $f {
            next unless $dir.add($f).f;
            @parts.push: "--- $f (head) ---\n" ~ $dir.add($f).slurp.lines.head(80).join("\n");
            last;
        }
    }
    my @files = walk($dir, 3).map(*.relative($dir)).sort.head(60);
    @parts.push: "--- file layout (up to 60 files) ---\n" ~ @files.join("\n");
    @parts.join("\n\n");
}

#| Files under $dir to a limited depth, skipping housekeeping directories.
sub walk(IO::Path $dir, Int $depth) {
    return () if $depth == 0;
    my @out;
    for (try $dir.dir.sort) // () -> $entry {
        next if $entry.basename eq any(<.git node_modules .precomp local>);
        if $entry.d { @out.append: walk($entry, $depth - 1) }
        else        { @out.push: $entry }
    }
    @out;
}

# ---------------------------------------------------------------- log / diff

sub log-text(IO::Path $path --> Str) is export {
    git-log($path) // "No Git history available for {$path.basename}\n";
}

#| Returns (exit-code, stdout, stderr) from Git.
sub diff-result(IO::Path $path, *@revs) is export {
    git-diff($path, |@revs);
}
