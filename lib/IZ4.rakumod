unit module IZ4;

use IZ4::Document;
use IZ4::Launcher;
use IZ4::Git;
use IZ4::Evidence;
use IZ4::Coach;

constant VERSION is export = '0.15.0';

#| A user-facing error: message only, no stack trace.
class X::IZ4 is Exception {
    has Str $.message is required;
}
sub user-error(Str $message) { X::IZ4.new(:$message).throw }

constant ROOT-NAME is export = 'IZ4';

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

#| The one canonicalisation rule the register and the CLI share, so the
#| same words get the same digest whatever a checkout did to the bytes.
#| Written once as spec/iz4-digest-1.md in the register; a later rule gets
#| a new id, this one never changes.
constant DIGEST-RULE is export = 'iz4-digest/1';

#| iz4-digest/1 of a file: sha256 of its bytes after strict UTF-8
#| validation (invalid UTF-8 has no canonical digest: Nil), one leading
#| byte-order mark removed, CRLF then CR made LF, and the trailing LFs
#| replaced by exactly one.  Nothing else changes: trailing spaces, blank
#| lines and Unicode forms are the words, and the digest must notice them.
#| Done on the bytes, not on Str, so no runtime's grapheme handling of
#| CRLF can get between the rule and the result.
sub canonical-digest(IO::Path $f --> Str) is export {
    my $raw = $f.slurp(:bin);
    return Nil without try $raw.decode('utf8');
    my @b = $raw.list;
    @b.splice(0, 3) if @b.elems >= 3 && @b[0] == 0xEF && @b[1] == 0xBB && @b[2] == 0xBF;
    my @out;
    my $i = 0;
    while $i < @b.elems {
        if @b[$i] == 0x0D {
            @out.push(0x0A);
            $i++ if $i + 1 < @b.elems && @b[$i + 1] == 0x0A;
        }
        else { @out.push(@b[$i]) }
        $i++;
    }
    @out.pop while @out.elems && @out.tail == 0x0A;
    @out.push(0x0A);
    my $tmp = $*TMPDIR.add("iz4-canon-{$*PID}-{(^1_000_000).pick}");
    LEAVE { try $tmp.unlink }
    $tmp.spurt(Blob.new(@out));
    sha256-file($tmp);
}

# ---------------------------------------------------------------- discovery

#| Walk upward from $start looking for a root IZ4 file.
sub find-root(IO::Path $start = $*CWD --> IO::Path) is export {
    my $dir = $start.resolve;
    loop {
        my $candidate = $dir.add(ROOT-NAME);
        return $candidate if $candidate.f;
        my $parent = $dir.parent;
        return Nil if $parent eq $dir;
        $dir = $parent;
    }
}

#| True when a CLI argument names a IZ4 document rather than a section or revision.
sub looks-like-file(Str $arg --> Bool) is export {
    so $arg.ends-with('.iz4') || $arg.IO.basename eq ROOT-NAME;
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

#| Where Invariants 0-4 are explained, for a reader with no CLI.
constant FOUNDATION-URL is export = 'https://iz4.you/invariant-zero';

#| The lines every new IZ4 opens with, so a reader knows what the
#| foundation below is, what it protects, and where to read about it.
constant INHERITANCE-COMMENT is export =
    "# Every IZ4 carries Invariants 0-4, the foundation, word for word: human intention protected.\n"
    ~ "# Read about them at {FOUNDATION-URL}. They are the same in every IZ4 and not yours to edit.\n"
    ~ '# Your own invariants begin at 5.';

#| Write the foundation into an IZ4 that lacks it or has an altered one.
#| Only the INVARIANT 0-4 blocks (with their BECAUSE) and the foundation
#| comment are touched; every other line stays.  Returns 'unchanged',
#| 'written' or 'replaced'.  Run on request only: this is the one case
#| where the tool rewrites lines, because the foundation was never the
#| owner's words to keep.
sub restore-foundation(IO::Path $path --> Str) is export {
    my $doc = IZ4::Document.load($path);
    return 'unchanged' if $doc.foundation-intact;
    my @lines = $path.slurp.lines;
    # every INVARIANT 0-4 block (in either label form) and the BECAUSE
    # directly after it, plus the foundation comment, are dropped
    my %drop;
    for $doc.blocks.kv -> $i, $b {
        next unless $b.kind eq 'INVARIANT' && $b.label.defined && $b.label ~~ /^ (\d+) / && +$0 < FIRST-PROJECT-NUMBER;
        %drop{$_} = True for $b.line .. $b.last-line;
        if $i + 1 < $doc.blocks && $doc.blocks[$i + 1].kind eq 'BECAUSE' {
            %drop{$_} = True for $doc.blocks[$i + 1].line .. $doc.blocks[$i + 1].last-line;
        }
    }
    my $replaced = %drop.elems > 0;
    # the header comment this tool wrote for earlier versions is brought up to date too
    my @old-header = "# Every IZ4 inherits Invariants 0-4: human intention protected.",
        "# Read them at {FOUNDATION-URL} ('iz4 invariants' prints them).",
        '# Project invariants begin at 5.';
    for @lines.kv -> $i, $l {
        if $l eq @old-header[0] && $i + 2 < @lines && @lines[$i + 1] eq @old-header[1] && @lines[$i + 2] eq @old-header[2] {
            @lines[$i .. $i + 2] = INHERITANCE-COMMENT.lines;
        }
    }
    for @lines.kv -> $i, $l {
        %drop{$i + 1} = True if $l.starts-with('# The foundation, Invariants 0-4.')
            || $l.starts-with("# 'iz4 check' refuses a file where they are missing")
            || $l.starts-with("# 'iz4 foundation --restore' puts them back");
    }
    # insert after the IS FOR WHO? block, else after IS FOR WHAT?, else at the end
    my $anchor = $doc.blocks.first(*.kind eq 'IS FOR WHO') // $doc.blocks.first(*.kind eq 'IS FOR WHAT');
    my $at = $anchor.defined ?? $anchor.last-line !! @lines.elems;
    my @out;
    for @lines.kv -> $i, $l {
        @out.push($l) unless %drop{$i + 1};
        if $i + 1 == $at {
            @out.push('') if @out && @out.tail ne '';
            @out.append(foundation-block().lines);
        }
    }
    if $at == @lines.elems && !$anchor.defined {
        @out.push('') if @out && @out.tail ne '';
        @out.append(foundation-block().lines);
    }
    # collapse runs of blank lines the removal may have left
    my @tidy;
    for @out -> $l { @tidy.push($l) unless $l eq '' && @tidy && @tidy.tail eq '' }
    $path.spurt(@tidy.join("\n") ~ "\n");
    $replaced ?? 'replaced' !! 'written';
}

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
        'IS FOR WHO?', |wrap($for-who.trim, WRAP-WIDTH), '',
        foundation-block();
}

#| Create a root IZ4 in $dir.  Refuses to overwrite; refuses empty answers.
sub init(IO::Path :$dir = $*CWD, Str :$for-what!, Str :$for-who! --> IO::Path) is export {
    my $path = $dir.add(ROOT-NAME);
    user-error("{ROOT-NAME} already exists here; not overwriting") if $path.e;
    user-error('what is this for? the answer cannot be empty') if $for-what.trim eq '';
    user-error('who is this for? the answer cannot be empty')  if $for-who.trim eq '';
    $path.spurt(template(:$for-what, :$for-who));
    $path;
}

# ---------------------------------------------------------------- show

#| Text of the whole document, or of one part: 'for-what', 'for-who' or
#| 'invariants'.
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
    user-error("unknown part '$part'; use for-what, for-who or invariants");
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

#| The effective invariant set: the foundation, then the
#| project's own.  This is what a person or agent should read before a
#| consequential change.
sub effective-text(IZ4::Document $doc, Str :$name = 'IZ4' --> Str) is export {
    my @out;
    @out.push: "IS FOR WHAT?\n" ~ wrap($doc.for-what // '(not stated)', WRAP-WIDTH).join("\n") ~ "\n";
    @out.push: "IS FOR WHO?\n"  ~ wrap($doc.for-who  // '(not stated)', WRAP-WIDTH).join("\n") ~ "\n";
    @out.append: FOUNDATION.map({ invariant-block(.<number>, .<name>, .<text>, .<because>, :note<foundation>) });
    @out.push: project-invariants-text($doc);
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
        return invariant-block($n, %f<name>, %f<text>, %f<because>, :note<foundation>);
    }
    with $doc.invariant($n) {
        return invariant-block($n, Str, .text, .because);
    }
    with withdrawn-in($path, $n) -> $when {
        return "Invariant $n was withdrawn in commit $when; its number is retired and never reused. 'iz4 diff {$when.words[0]}~1 {$when.words[0]}' shows what it said.\n";
    }
    if $n ∈ withdrawn-in-text($path) {
        return "Invariant $n was withdrawn; its number is retired and never reused. 'iz4 log' shows when, where there is Git history.\n";
    }
    my @nums = $doc.invariants.map(*.number).grep(*.defined);
    user-error("no invariant $n in {$path.basename}; "
        ~ (@nums ?? "its own are {@nums.join(', ')}, and 0-4 are the foundation"
                 !! "it has none of its own yet, and 0-4 are the foundation"));
}

# ------------------------------------------------------------- withdraw

#| Take a project invariant out of the file: its INVARIANT block, its
#| BECAUSE and the blank line before them.  Nothing else is touched, Git
#| keeps the words, and the number is retired: 'iz4 add' never hands a
#| number the file has carried to a different invariant (Invariant 13).
#| The foundation, 0-4, cannot be withdrawn by any project (Invariant 4).
#| Returns the invariant as it was.  The caller confirms with a person
#| first: this discards their words only on their say-so (Invariant 11).
sub withdraw-invariant(IO::Path $path, Int $n --> IZ4::Document::Invariant) is export {
    user-error("Invariant $n is the foundation's {FOUNDATION[$n]<name>}: Invariants 0-4 bind every project and cannot be withdrawn by one (Invariant 4)")
        if $n < FIRST-PROJECT-NUMBER;
    my $doc = IZ4::Document.load($path);
    my $inv = $doc.invariant($n);
    without $inv {
        with withdrawn-in($path, $n) -> $when { user-error("Invariant $n was already withdrawn in commit $when") }
        user-error("Invariant $n was already withdrawn") if $n ∈ withdrawn-in-text($path);
        user-error("no invariant $n in {$path.basename}; 'iz4 show invariants' lists its own");
    }
    my @lines = $doc.lines;
    my $from  = $inv.line - 1;
    my $to    = ($inv.because-line.defined
        ?? ($doc.blocks.first({ .kind eq 'BECAUSE' && .line == $inv.because-line }).last-line)
        !! $inv.last-line) - 1;
    # One comment line stands where it was, so every reader sees why the
    # number is missing, and so the number stays retired even where there
    # is no Git history to consult.
    @lines.splice($from, $to - $from + 1, withdrawn-comment($n));
    @lines.pop while @lines && @lines[*-1].trim eq '';
    $path.spurt(@lines.join("\n") ~ "\n");
    $inv;
}

sub withdrawn-comment(Int $n --> Str) { "# Invariant $n was withdrawn on {Date.today}; its number is retired." }

#| The numbers a file's own comments say were withdrawn.
sub withdrawn-in-text(IO::Path $path --> List) is export {
    $path.slurp.lines.map({ $_ ~~ /^ '#' \h* 'Invariant' \h+ (\d+) \h+ 'was withdrawn' / ?? +$0 !! Empty }).List;
}

#| The commit in which Invariant $n left the file, as 'HASH (DATE)', or
#| Str when Git does not show one.
sub withdrawn-in(IO::Path $path, Int $n --> Str) is export {
    my ($rc, $log, $) = git($path, 'log', '-p', '--follow', '--date=short', '--format=%x01%h %ad', '--', $path.basename);
    return Str if $rc != 0;
    for $log.split("\x01").grep(* ne '') -> $commit {
        my ($head, @body) = $commit.lines;
        my $gone = @body.first({ $_ ~~ /^ '-INVARIANT' \h+ $n \h* $/ }).defined;
        my $back = @body.first({ $_ ~~ /^ '+INVARIANT' \h+ $n \h* $/ }).defined;
        return "{$head.words[0]} ({$head.words[1]})" if $gone && !$back;
    }
    Str;
}

#| Test files that name Invariant $n, relative to $root: after a
#| withdrawal they are the next thing to look at.
sub tests-naming(IO::Path $root, Int $n --> List) is export {
    test-files($root).grep({ (try .slurp) andthen .match(/ 'Invariant' \h+ $n <!before \d> /) }).map(*.relative($root)).List;
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

#| The highest project number this file has ever carried, from its Git
#| history as well as its current text, so a retired number is never
#| handed to a different invariant (Invariant 13).  Without Git, or for an
#| untracked file, only the current text is known.
sub highest-ever-number(IO::Path $path --> Int) is export {
    my $doc = IZ4::Document.load($path);
    my $highest = (-1, |$doc.invariants.map(*.number).grep(*.defined), |withdrawn-in-text($path)).max;
    my ($rc, $log, $) = git($path, 'log', '-p', '--follow', '--format=', '--', $path.basename);
    if $rc == 0 {
        for $log.lines -> $l {
            if $l ~~ /^ <[+\-]> 'INVARIANT' \h+ (\d+) \h* $/ { $highest max= +$0 }
        }
    }
    $highest;
}

#| The next number to give a new invariant: after every number the file
#| has ever carried, and never below 5.
sub next-free-number(IO::Path $path --> Int) is export {
    max(FIRST-PROJECT-NUMBER, highest-ever-number($path) + 1);
}

#| Add a project invariant, with its BECAUSE when given.  It takes the
#| next free number from 5 unless :$number chooses one; 0-4, numbers in
#| use, and numbers the file has ever used are refused.  Returns the number
#| written.  Existing text is never touched: the new block is appended.
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
        user-error("Invariant $n was used before in {$path.basename} (see 'iz4 log'); a number is never reused for a different invariant, so pick a fresh one")
            if $n <= highest-ever-number($path);
    }
    else { $n = next-free-number($path) }
    my $reason = ($because // '').trim;

    my @lines = $doc.lines;
    @lines.pop while @lines && @lines[*-1].trim eq '';
    @lines.append: '', "INVARIANT $n", |wrap($value, WRAP-WIDTH);
    @lines.append: '', 'BECAUSE', |wrap($reason, WRAP-WIDTH) if $reason ne '';
    $path.spurt(@lines.join("\n") ~ "\n");
    $n;
}

# ---------------------------------------------------------------- because

#| Set the BECAUSE of project invariant $n.  An existing one needs
#| :replace.  Returns the number.
sub set-because(IO::Path $path, Int $n, Str $text, Bool :$replace = False --> Int) is export {
    my $reason = $text.trim;
    user-error('nothing to set: the reason is empty') if $reason eq '';
    my $doc = IZ4::Document.load($path);
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
    user-error("Invariant $n is the foundation's; its reasons are the same in every IZ4 and not yours to change") if $n < FIRST-PROJECT-NUMBER;
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
#| only the header line of each one numbered is touched.  Returns (line, number) pairs, empty when there was nothing
#| to do.
sub number-invariants(IO::Path $path --> List) is export {
    my @lines = IZ4::Document.load($path).lines;
    my @done  = number-lines(@lines, from => next-free-number($path));
    $path.spurt(@lines.join("\n") ~ "\n") if @done;
    @done;
}

#| The same, on a whole IZ4 held as @lines, changed in place.
sub number-lines(@lines, Int :$from --> List) is export {
    my $doc  = IZ4::Document.parse(@lines.join("\n") ~ "\n");
    my @todo = $doc.unnumbered-invariants;
    return () unless @todo;
    my $next = max($from // 0, $doc.next-number);
    my @done;
    for @todo -> $inv {
        @lines[$inv.line - 1] = "INVARIANT $next";
        @done.push: ($inv.line, $next++);
    }
    @done;
}

# ---------------------------------------------------------------- suggest

#| The agent command behind `iz4 suggest`: overridable, external, optional.
sub agent-cmd(--> Str) is export { %*ENV<IZ4_AGENT_CMD> // 'claude -p' }

#| The prompt for repository analysis.  Its job is to keep IZ4 small.
sub suggest-prompt(Str :$current = '', Str :$evidence = '' --> Str) is export {
    q:to/END/ ~ ($current.trim || '(none yet)') ~ "\n\nEvidence from the codebase:\n" ~ $evidence ~ "\n";
    You are helping a developer find the few enduring invariants of the
    system in this repository, for its IZ4 file.

    IZ4 means Is For.  An IZ4 answers three questions: what is this system
    for, who is it for, and what must remain true for it to keep serving
    them.  It is deliberately incomplete.

    Do not try to make IZ4 complete.  Try to make it small.

    Every IZ4 carries Invariants 0-4, the foundation (humans first, do no
    harm, human agency, honesty, the foundation holds), word for word.  Do
    not restate them; propose only this project's own invariants.

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

sub agent-suggest(IO::Path $dir = $*CWD, Str :$cmd, Str :$current = '' --> Hash) is export {
    my $prompt = suggest-prompt(:$current, evidence => gather-context($dir));
    note "asking agent ({$cmd // agent-label()}) for candidate invariants in {$dir.resolve} ...";
    parse-suggestions(ask-agent($prompt, :root($dir), :$cmd));
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

# ---------------------------------------------------------------- update

#| The short commit id of this copy, or Str for a standalone file.
sub own-revision(--> Str) is export {
    my $root = own-checkout() // return Str;
    my ($rc, $out, $) = git($root.add('bin').add('iz4'), 'rev-parse', '--short', 'HEAD');
    $rc == 0 ?? $out.trim !! Str;
}

#| Where this copy of iz4 lives: the checkout two levels above bin/iz4,
#| or Nil when this copy is not a Git checkout (a standalone binary).
sub own-checkout(--> IO::Path) is export {
    my $root = try $*PROGRAM.resolve.parent(2);
    $root.defined && $root.add('.git').e && $root.add('bin').add('iz4').e ?? $root !! Nil;
}

#| Is the file this process was started from a standalone executable
#| (ELF, Mach-O or PE, by its first bytes)?  Anything else is a script
#| something else installed and owns: zef's wrapper, a copy of bin/iz4.
sub program-is-binary(--> Bool) is export {
    my $self = try $*PROGRAM.resolve;
    return False without $self;
    my $head = try { my $fh = $self.open(:bin); LEAVE { .close with $fh }; $fh.read(4) };
    return False unless $head.defined && $head.elems == 4;
    my @b = $head.list;
    so  (@b[0] == 0x7F && @b[1] == 0x45 && @b[2] == 0x4C && @b[3] == 0x46)      # ELF
     || (@b[0] == 0x4D && @b[1] == 0x5A)                                         # PE (MZ)
     || (@b eqv [0xCF, 0xFA, 0xED, 0xFE]) || (@b eqv [0xFE, 0xED, 0xFA, 0xCF])   # Mach-O, either order
     || (@b eqv [0xCA, 0xFE, 0xBA, 0xBE]) || (@b eqv [0xBE, 0xBA, 0xFE, 0xCA]);  # universal Mach-O
}

#| Where the standalone files are published, and the file for this machine.
constant RELEASES is export = 'https://github.com/nige123/cli.iz4.you/releases';
constant RELEASES-API is export = 'https://api.github.com/repos/nige123/cli.iz4.you/releases/latest';

#| The directory holding a release's files: the explicit tag, never the
#| 'latest' redirect, which GitHub serves from a cache that can lag the
#| release itself by minutes.
sub release-base(Str $tag --> Str) { %*ENV<IZ4_RELEASE_URL> // "{RELEASES}/download/$tag" }

#| The release file built for this operating system and processor, or
#| Str when none is published for them.
sub own-asset(--> Str) is export {
    my $arch = $*KERNEL.hardware.lc;
    $arch = 'aarch64' if $arch eq 'arm64';
    given $*KERNEL.name.lc {
        when 'linux'  { $arch eq 'x86_64' | 'aarch64' ?? "iz4-linux-$arch" !! Str }
        when 'darwin' { 'iz4-macos-universal' }
        when /win/    { $arch eq 'x86_64' | 'amd64' ?? 'iz4-windows-x64.exe' !! Str }
        default       { Str }
    }
}

#| The newest published tag (like v0.3.0), or Str when none can be found.
#| GitHub's releases API says which release is latest; a test release
#| directory names it in latest.txt.
sub latest-tag(--> Str) is export {
    if %*ENV<IZ4_RELEASE_URL> {
        my $p = run 'curl', '-fsSL', "{%*ENV<IZ4_RELEASE_URL>}/latest.txt", :out, :err;
        my $tag = $p.out.slurp(:close).trim; $p.err.slurp(:close);
        return $p.exitcode == 0 && $tag ?? $tag !! Str;
    }
    my $p = run 'curl', '-fsSL', '-H', 'Accept: application/vnd.github+json', RELEASES-API, :out, :err;
    my $body = $p.out.slurp(:close); $p.err.slurp(:close);
    return Str if $p.exitcode != 0;
    with $body.match(/ '"tag_name"' \s* ':' \s* '"' (<-["]>+) '"' /) {
        my $tag = ~$0;
        return $tag if $tag ~~ /^ 'v' \d/;
    }
    Str;
}

sub fetch(Str $url, IO::Path $to --> Bool) {
    my $p = run 'curl', '-fsSL', '-o', $to.Str, $url, :out, :err;
    $p.out.slurp(:close); $p.err.slurp(:close);
    $p.exitcode == 0 && $to.f;
}

#| Update a standalone iz4 in place from the published files.
sub binary-update(Bool :$check = False --> Hash) is export {
    my $asset = own-asset() // return %( state => 'failed',
        note => "no published iz4 for {$*KERNEL.name} on {$*KERNEL.hardware}; install from source with the install script" );
    my $tag = latest-tag() // return %( state => 'failed', note => "could not find the latest release at {RELEASES}" );
    my $from = "v{VERSION}";
    return %( state => 'current', :$from, n => 0 ) if $tag eq $from;
    return %( state => 'behind', :$from, n => 1, commits => ("release $tag",) ) if $check;

    my $tmp = $*TMPDIR.add("iz4-update-{$*PID}");
    $tmp.mkdir;
    my $new = $tmp.add($asset);
    fetch("{release-base($tag)}/$asset", $new) && fetch("{release-base($tag)}/$asset.sha256", $tmp.add("$asset.sha256"))
        or return %( state => 'failed', note => "could not download $asset $tag from {release-base($tag)}" );
    my $expected = $tmp.add("$asset.sha256").slurp.lc.match(/ <[0..9a..f]> ** 64 /);
    my $got = sha256-file($new);
    return %( state => 'failed', note => "checksum mismatch for $asset $tag; nothing was replaced" )
        unless $expected && ~$expected eq $got;
    $new.chmod(0o755);
    my $probe = run $new.Str, 'version', :out, :err;
    $probe.out.slurp(:close); $probe.err.slurp(:close);
    return %( state => 'failed', note => "the downloaded $asset does not run here; nothing was replaced" ) if $probe.exitcode != 0;

    my $self = $*PROGRAM.resolve;
    if $*KERNEL.name.lc ~~ /win/ {
        # a running .exe cannot be overwritten, but it can be renamed
        my $old = $self.parent.add($self.basename ~ '.old');
        $old.unlink if $old.e;
        $self.rename($old);
    }
    $new.rename($self) or return %( state => 'failed', note => "could not replace {$self}; is it writable?" );
    %( state => 'updated', :$from, to => $tag, n => 1, commits => ("release $tag",) );
}

#| Update this copy of iz4 to the latest published version, or with
#| :check only say whether one exists.  Returns a hash: 'state' is one of
#| current, behind, updated, dirty or failed, with 'from', 'to',
#| 'commits' (their subjects) and 'note' as apply.  A Git checkout
#| fast-forwards from its own remote; a standalone file downloads the
#| newest published file for this machine and replaces itself.
sub self-update(Bool :$check = False --> Hash) is export {
    # Neither a checkout nor a standalone executable: a script some
    # package manager installed (zef, from raku.land).  Replacing it with a
    # downloaded file would corrupt that installation, so say whose job the
    # update is and touch nothing.
    return %( state => 'managed', from => VERSION,
              note => "this iz4 was installed as a Raku distribution; update it with: zef upgrade IZ4" )
        if !own-checkout().defined && !program-is-binary();
    my $root = own-checkout() // return binary-update(:$check);
    my $marker = $root.add('bin').add('iz4');
    my sub g(*@a) { git($marker, |@a) }

    my ($rc, $dirty, $) = g('status', '--porcelain', '--untracked-files=no');
    return %( state => 'dirty', note => "$root has local changes; this looks like a developer checkout, so update it yourself" )
        if $rc == 0 && $dirty.trim;

    my ($rf, $, $ferr) = g('fetch', '--quiet');
    return %( state => 'failed', note => "could not reach the update source: {$ferr.trim.lines.head // 'git fetch failed'}" ) if $rf != 0;

    my ($, $from, $) = g('rev-parse', '--short', 'HEAD');
    my ($rb, $behind, $) = g('rev-list', '--count', 'HEAD..@{u}');
    return %( state => 'failed', note => 'this checkout tracks no upstream branch; re-run the installer' ) if $rb != 0;
    my $n = +$behind.trim;
    my ($, $log, $) = g('log', '--format=%s', 'HEAD..@{u}');
    my @commits = $log.lines;
    return %( state => 'current', from => $from.trim, :$n ) if $n == 0;
    return %( state => 'behind', from => $from.trim, :$n, :@commits ) if $check;

    my ($rp, $, $perr) = g('pull', '--ff-only', '--quiet');
    return %( state => 'failed', note => "update failed: {$perr.trim.lines.head // 'git pull failed'}; re-run the installer" ) if $rp != 0;
    my ($, $to, $) = g('rev-parse', '--short', 'HEAD');
    # prove the updated copy still runs before claiming success
    my $probe = run $*EXECUTABLE, '-I', $root.add('lib').Str, $marker.Str, 'version', :out, :err;
    $probe.out.slurp(:close); $probe.err.slurp(:close);
    return %( state => 'failed', note => "updated to {$to.trim} but iz4 no longer runs; re-run the installer" ) if $probe.exitcode != 0;
    %( state => 'updated', from => $from.trim, to => $to.trim, :$n, :@commits );
}

# ---------------------------------------------------------------- log / diff

sub log-text(IO::Path $path --> Str) is export {
    git-log($path) // "No Git history available for {$path.basename}\n";
}

#| Returns (exit-code, stdout, stderr) from Git.
sub diff-result(IO::Path $path, *@revs) is export {
    git-diff($path, |@revs);
}
