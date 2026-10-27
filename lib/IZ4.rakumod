unit module IZ4;

use IZ4::Document;
use IZ4::Git;
use IZ4::Evidence;
use IZ4::Coach;

constant VERSION is export = '0.30.2';

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

#| sha256 of a string's UTF-8 bytes.
sub sha256-text(Str $s --> Str) is export {
    my $tmp = $*TMPDIR.add("iz4-text-{$*PID}-{(^1_000_000_000).pick}.txt");
    LEAVE { try $tmp.unlink }
    $tmp.spurt($s);
    sha256-file($tmp);
}

#| The digest of one invariant given as words, in the rules of the earlier
#| forms: iz4-invariant/4 when :reach says it is a clauses invariant, else
#| the named form's rule, with the foundation's own digest for its words.
#| Those forms are read only to migrate; a card's digest, iz4-invariant/5,
#| comes from invariant-digest-of, the rule for any parsed invariant.  The
#| name says which commitment; the digest says which wording of it.
sub invariant-digest(Str $id, Str $text, Str $because?, Str :$reach --> Str) is export {
    return sha256-text(canonical-clauses($id, $reach, $text, $because // '')) with $reach;
    is-foundation-id($id) && foundation-matches($id, $text, $because // '')
        ?? foundation-digest-of($id)
        !! sha256-text(canonical-invariant($id, $text, $because // ''));
}

my %FOUNDATION-DIGESTS;
#| The digest of one invariant as parsed, in the rule of its form:
#| iz4-invariant/5 for a card, the older rules for the earlier forms.
sub invariant-digest-of(IZ4::Document::Invariant $inv --> Str) is export { sha256-text($inv.canonical) }

#| The digest of one foundation invariant in the earlier named form's words.
sub foundation-digest-of(Str $id --> Str) is export {
    %FOUNDATION-DIGESTS{$id} //= do {
        my %f = foundation-entry($id);
        sha256-text(canonical-invariant($id, %f<text>, %f<because>));
    };
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
    # The walk must end on every system.  At a root the parent is the
    # directory itself on some, and a path that only grows ('D:\..') on
    # others, so it stops when the path stops getting shorter, when it
    # comes round to one already seen, and in any case after 128 levels.
    my %seen;
    for ^128 {
        my $candidate = $dir.add(ROOT-NAME);
        return $candidate if $candidate.f;
        my $here = $dir.Str;
        %seen{$here} = True;
        my $parent = $dir.parent;
        my $up = $parent.Str;
        return Nil if $up eq $here || %seen{$up} || $up.chars >= $here.chars;
        $dir = $parent;
    }
    Nil;
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

#| Where the foundation is explained, for a reader with no CLI.
constant FOUNDATION-URL is export = 'https://iz4.you/foundation';

#| Where earlier versions said it was; that address redirects here.
my constant OLD-FOUNDATION-URL = 'https://iz4.you/invariant-zero';

#| The lines every new IZ4 opens with, so a reader knows what the
#| foundation below is, what it protects, and where to read about it.
constant INHERITANCE-COMMENT is export =
    "# Every IZ4 carries the foundation word for word: human intention protected.\n"
    ~ "# It begins with Invariant Zero, humans first: {FOUNDATION-URL}. It is the same in every IZ4 and not yours to edit.\n"
    ~ "# Your own invariants are named under your project's domain.";

#| The header comments earlier versions wrote, brought up to date when the
#| foundation is restored or a file is migrated.
my @OLD-HEADERS =
    ("# Every IZ4 inherits Invariants 0-4: human intention protected.",
     "# Read them at {OLD-FOUNDATION-URL} ('iz4 invariants' prints them).",
     '# Project invariants begin at 5.'),
    ("# Every IZ4 carries Invariants 0-4, the foundation, word for word: human intention protected.",
     "# Read about them at {OLD-FOUNDATION-URL}. They are the same in every IZ4 and not yours to edit.",
     '# Your own invariants begin at 5.'),
    ("# Every IZ4 carries the five foundation invariants word for word: human intention protected.",
     "# Read about them at {OLD-FOUNDATION-URL}. They are the same in every IZ4 and not yours to edit.",
     "# Your own invariants are named under your project's domain."),
    ("# Every IZ4 carries the foundation, Invariants 0 to 4, word for word: human intention protected.",
     "# It begins with Invariant Zero, humans first: {OLD-FOUNDATION-URL}. It is the same in every IZ4 and not yours to edit.",
     "# Your own invariants are named under your project's domain."),
    ("# Every IZ4 carries the foundation word for word: human intention protected.",
     "# It begins with Invariant Zero, humans first: {OLD-FOUNDATION-URL}. It is the same in every IZ4 and not yours to edit.",
     "# Your own invariants are named under your project's domain.");

#| @lines with every foundation block (and, in the earlier named form, its
#| BECAUSE), the foundation comment and nothing else removed, the opening
#| comment brought up to date, and the foundation written as cards (or in
#| the earlier form asked for) where the first block stood: else after
#| IS FOR WHO?, else after IS FOR WHAT?, else at the end.
sub with-foundation(IZ4::Document $doc, @source, Bool :$to-clauses = False, Bool :$to-card = False, Bool :$last = False --> List) {
    my @lines = @source;
    my $card    = $to-card || (!$to-clauses && $doc.form eq 'card');
    my $clauses = !$card && ($to-clauses || $doc.form eq 'clauses');
    my %drop;
    for $doc.foundation-spans -> ($from, $to) { %drop{$_} = True for $from .. $to }
    for @OLD-HEADERS -> @old {
        for @lines.kv -> $i, $l {
            if $l eq @old[0] && $i + 2 < @lines && @lines[$i + 1] eq @old[1] && @lines[$i + 2] eq @old[2] {
                @lines[$i .. $i + 2] = INHERITANCE-COMMENT.lines;
            }
        }
    }
    for @lines.kv -> $i, $l {
        %drop{$i + 1} = True if $l eq FOUNDATION-RULE-OFF
            || $l.starts-with('# The foundation, Invariants 0-4.')
            || $l.starts-with('# The foundation. Every IZ4 carries these five invariants')
            || $l.starts-with('# The foundation, Invariants 0 to 4:')
            || $l.starts-with('# The foundation: the same words in every IZ4.')
            || $l.starts-with('# Invariant Zero, humans-first.iz4.you, is the foundation')
            || $l.starts-with("# 'iz4 check' refuses a file where any of it is missing")
            || $l.starts-with("# 'iz4 foundation restore' puts it back")
            || $l.starts-with('# If any of it goes missing or changes,')
            || $l.starts-with("# 'iz4 check' refuses a file where they are missing")
            || $l.starts-with("# 'iz4 foundation restore' puts them back")
            # as written before an action was a word
            || $l.starts-with("# 'iz4 foundation --restore' puts it back")
            || $l.starts-with("# 'iz4 foundation --restore' puts them back");
    }
    my $anchor = $doc.blocks.first(*.kind eq 'IS FOR WHO') // $doc.blocks.first(*.kind eq 'IS FOR WHAT');
    my $at = $last ?? @lines.elems !! $doc.foundation-spans ?? $doc.foundation-spans.map(*[0]).min - 1
          !! $anchor.defined ?? $anchor.last-line !! @lines.elems;
    # the comment directly above the first block goes with it
    $at-- while $at > 0 && %drop{$at};
    my @out;
    my $placed = False;
    my sub place() {
        @out.push('') if @out && @out.tail ne '';
        @out.append(foundation-block(:$clauses, :$card).lines);
        @out.push('');
        $placed = True;
    }
    place() if $at == 0;
    for @lines.kv -> $i, $l {
        @out.push($l) unless %drop{$i + 1};
        place() if $i + 1 == $at && !$placed;
    }
    place() unless $placed;
    my @tidy;
    for @out -> $l { @tidy.push($l) unless $l eq '' && @tidy && @tidy.tail eq '' }
    @tidy.pop while @tidy && @tidy.tail eq '';
    @tidy;
}

#| Write the foundation into an IZ4 that lacks it or has an altered one,
#| in the form of the file.  Only the foundation's own cards (blocks, with
#| their BECAUSE, in the earlier named form) and the foundation comment
#| are touched; every other line stays.  Returns 'unchanged', 'written',
#| 'replaced', or 'tidied' when the words were right and only the comments
#| an earlier version wrote came up to date.  Run on request only: this is
#| the one case where the tool rewrites lines, because the foundation was
#| never the owner's words to keep.
sub restore-foundation(IO::Path $path --> Str) is export {
    my $doc = IZ4::Document.load($path);
    my $was = $path.slurp;
    my $now = with-foundation($doc, $was.lines).join("\n") ~ "\n";
    # the words are right but the comments around them are an earlier version's
    return $now eq $was ?? 'unchanged' !! do { $path.spurt($now); 'tidied' } if $doc.foundation-intact;
    my $replaced = so $doc.foundation-spans;
    $path.spurt($now);
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

# ---------------------------------------------------------- governance

#| Set what one promise's words require to change, and with it what is
#| checked: 'exploring' (no approval; linked tests warn) or 'established'
#| (signed human approval; linked tests block).  Only the two governance
#| lines of that card are rewritten.  Returns the stage now written, or
#| 'unchanged'.  Lowering is a change the gate asks a person about at
#| commit time, like any other; this only writes the words.
sub set-governance(IO::Path $path, Str $id, Str $stage where 'exploring' | 'established' --> Str) is export {
    my $doc = check-doc($path);
    user-error("{$path.basename} is not in the card form: 'iz4 migrate' moves it there first") unless $doc.form eq 'card';
    my $inv = $doc.invariant($id) // user-error("no promise named $id in {$path.basename}");
    my $change = $stage eq 'exploring' ?? CHANGE-FREE !! CHANGE-SIGNED;
    return 'unchanged' if ($inv.change // '') eq $change;
    my @lines = $path.lines;
    my $ch = $doc.blocks.first({ .kind eq 'CHANGES REQUIRE' && .line > $inv.line && .line <= $inv.last-line }) // user-error("$id has no CHANGES REQUIRE line to rewrite");
    my $ck = $doc.blocks.first({ .kind eq 'CHECKED WITH' && .line > $inv.line && .line <= $inv.last-line });
    # the later span first, so line numbers above it stay true
    my @edits;
    @edits.push: ($ch.line, $ch.last-line, card-field-lines('CHANGES REQUIRE', ($change,), :col(18)));
    @edits.push: ($ck.line, $ck.last-line, card-field-lines('CHECKED WITH', checks-for($change), :col(18))) if $ck.defined;
    for @edits.sort({ -$_[0] }) -> ($from, $to, @new) { @lines.splice($from - 1, $to - $from + 1, @new) }
    unless $ck.defined {
        my $at = $ch.line - 1 + card-field-lines('CHANGES REQUIRE', ($change,), :col(18)).elems;
        @lines.splice($at, 0, card-field-lines('CHECKED WITH', checks-for($change), :col(18)));
    }
    my $was = $path.slurp;
    $path.spurt(@lines.join("\n") ~ "\n");
    my $got = IZ4::Document.load($path);
    unless $got.ok && $got.invariant($id).defined && $got.invariant($id).change eq $change {
        $path.spurt($was);
        user-error("$id would not read back with its governance as meant, so nothing was written; this is a bug in iz4, please report it");
    }
    $stage;
}

# ---------------------------------------------------------------- init

#| A new IZ4: its domain in the header, the two answers that are its
#| heart, and the foundation as cards.  Nothing else.
sub template(Str :$for-what!, Str :$for-who!, Str :$namespace --> Str) is export {
    return join "\n",
        "{ROOT-NAME} $namespace", '',
        INHERITANCE-COMMENT, '',
        |purpose-lines('IS FOR WHAT?', $for-what.trim), '',
        |purpose-lines('IS FOR WHO?', $for-who.trim), '',
        foundation-block(:card) with $namespace;
    join "\n",
        ROOT-NAME, '',
        INHERITANCE-COMMENT, '',
        'IS FOR WHAT?', |wrap($for-what.trim, WRAP-WIDTH), '',
        'IS FOR WHO?', |wrap($for-who.trim, WRAP-WIDTH), '',
        foundation-block();
}

#| One of the two questions as a card file writes it: its answer on the
#| same line, wrapped under it.
sub purpose-lines(Str $label, Str $text --> List) is export {
    my $head = $label.fmt('%-14s');
    my @w = wrap-safely($text, WRAP-WIDTH - $head.chars);
    @w = ('',) unless @w;
    (($head ~ @w[0]), |@w[1 .. *].map({ ' ' x $head.chars ~ $_ })).List;
}

#| Create a root IZ4 in $dir.  Refuses to overwrite; refuses empty answers.
#| Without a namespace the earlier named form is written, which the CLI
#| never asks for: it always has one, because the header names it.
sub init(IO::Path :$dir = $*CWD, Str :$for-what!, Str :$for-who!, Str :$namespace --> IO::Path) is export {
    my $path = $dir.add(ROOT-NAME);
    user-error("{ROOT-NAME} already exists here; not overwriting") if $path.e;
    user-error('what is this for? the answer cannot be empty') if $for-what.trim eq '';
    user-error('who is this for? the answer cannot be empty')  if $for-who.trim eq '';
    with $namespace {
        with namespace-problem($_) -> $why { user-error("'$namespace' cannot be this project's domain: $why") if $why }
    }
    $path.spurt(template(:$for-what, :$for-who, :$namespace));
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

#| One invariant as a reader sees it: a card when it has ALWAYS items,
#| else in the earlier clauses or named layout.
sub invariant-block(Str $label, Str $text, Str $because?, Str :$reach, :@always, :@protects, Str :$change --> Str) {
    if @always {
        my $ch = $change // CHANGE-SIGNED;
        return card-lines((is-foundation-id($label) ?? 'FOUNDATION' !! 'PROMISE'), $label, $reach // '', @always, (@protects || ($because // '',)), $ch).join("\n") ~ "\n";
    }
    with $reach { return clauses-invariant-lines($label, $reach, $text, $because // '').join("\n") ~ "\n" }
    my @out = ("INVARIANT $label");
    @out.append: wrap($text, WRAP-WIDTH);
    if $because.defined && $because.trim {
        @out.push: 'BECAUSE';
        @out.append: wrap($because, WRAP-WIDTH);
    }
    @out.join("\n") ~ "\n";
}

sub project-invariants-text(IZ4::Document $doc --> Str) {
    return "(no promises of its own yet: 'iz4 add' helps you find one)\n" unless $doc.invariants;
    $doc.invariants.map({
        .id.defined
            ?? invariant-block(.id, .text, .because, :reach(.reach), :always(.always-items), :protects(.protects-items), :change(.change))
            !! "INVARIANT (unnamed)\n" ~ wrap(.text, WRAP-WIDTH).join("\n") ~ "\n"
    }).join("\n");
}

#| The foundation as a reader sees it, in the form of the file.
sub foundation-text(Bool :$clauses = False, Bool :$card = False --> Str) is export {
    return FOUNDATION-CARD.map({ invariant-block(.<id>, '', '', :reach(.<when>), :always(.<always>.list), :protects(.<protects>.list), :change(CHANGE-FOUNDATION)) }).join("\n") if $card;
    return FOUNDATION-CLAUSES.map({ invariant-block(.<id>, .<text>, .<because>, :reach(.<reach>)) }).join("\n") if $clauses;
    FOUNDATION.map({ invariant-block(.<id>, .<text>, .<because>) }).join("\n");
}

#| The effective invariant set: the foundation, then the
#| project's own.  This is what a person or agent should read before a
#| consequential change.
sub effective-text(IZ4::Document $doc, Str :$name = 'IZ4' --> Str) is export {
    my @out;
    @out.push: "IS FOR WHAT?\n" ~ wrap($doc.for-what // '(not stated)', WRAP-WIDTH).join("\n") ~ "\n";
    @out.push: "IS FOR WHO?\n"  ~ wrap($doc.for-who  // '(not stated)', WRAP-WIDTH).join("\n") ~ "\n";
    @out.push: foundation-text(:clauses($doc.form eq 'clauses'), :card($doc.form eq 'card'));
    @out.push: project-invariants-text($doc);
    @out.join("\n");
}

#| Which invariant a person means.  The full name always works.  So does
#| its first part alone (owner-adjusted) when exactly one invariant in the
#| file begins with it.  A digit 0 to 4, the numbering older files gave
#| the foundation, still finds the foundation invariant at that place.
#| Returns the identity, or Str.
sub resolve-identity(IZ4::Document $doc, Str $ref, :@also --> Str) is export {
    my $raw = $ref.trim.subst(/:i^ 'invariant' \s+ /, '').subst(/ ':' $/, '');
    # Older files numbered the foundation 0 to 4, and Invariant Zero has a
    # by-name of its own: either still finds the foundation invariant at
    # that place.  Only the foundation: nothing else ever had a number.
    my $clauses = $doc.form eq 'clauses';
    my $card    = $doc.form eq 'card';
    return foundation-at(0, :$clauses, :$card) if $raw.lc eq 'zero' | 'iz';
    return foundation-at(+$raw, :$clauses, :$card) if $raw ~~ /^ <[0..4]> $/;
    # a foundation invariant asked for by a name it used to have answers under the one it has now
    unless $clauses || $card { with foundation-renamed($raw) // foundation-renamed($raw ~ '.' ~ FOUNDATION-NAMESPACE) { return $_ } }
    my @all = |foundation-ids(:$clauses, :$card), |$doc.invariants.map(*.id).grep(*.defined), |$doc.retired, |@also;
    return $raw if @all.first(* eq $raw).defined;
    my @starts = @all.grep(*.starts-with("$raw.")).unique;
    @starts == 1 ?? @starts[0] !! Str;
}

sub own-names(IZ4::Document $doc --> Str) {
    my @ids = $doc.invariants.map(*.id).grep(*.defined);
    @ids ?? "its own are {@ids.join(', ')}" !! 'it has none of its own yet';
}

#| One invariant by name.  The foundation's names always answer.
sub invariant-text(IO::Path $path, Str $ref --> Str) is export {
    my $doc = IZ4::Document.load($path);
    user-error("'$ref' is a number, and only the foundation, 0 to 4, has an order; 'iz4 show invariants' lists the names")
        if $ref.trim ~~ /:i^ ['invariant' \s+]? \d+ ':'? $/ && $ref.trim !~~ /:i^ ['invariant' \s+]? <[0..4]> ':'? $/;
    my $id = resolve-identity($doc, $ref)
        // user-error("no invariant '$ref' in {$path.basename}; {own-names($doc)}, and the foundation is {foundation-ids(:clauses($doc.form eq 'clauses'), :card($doc.form eq 'card')).join(', ')}");
    my $clauses = $doc.form eq 'clauses';
    if $doc.form eq 'card' {
        with FOUNDATION-CARD.first({ .<id> eq $id }) -> %f {
            return invariant-block($id, '', '', :reach(%f<when>), :always(%f<always>.list), :protects(%f<protects>.list), :change(CHANGE-FOUNDATION));
        }
    }
    with ($clauses ?? FOUNDATION-CLAUSES.first({ .<id> eq $id }) !! foundation-entry($id)) -> %f {
        return invariant-block($id, %f<text>, %f<because>, :reach($clauses ?? %f<reach> !! Str));
    }
    with $doc.invariant($id) { return invariant-block($id, .text, .because, :reach(.reach), :always(.always-items), :protects(.protects-items), :change(.change)) }
    with withdrawn-in($path, $id) -> $when {
        return "PROMISE $id was withdrawn in commit $when; its name is retired and never reused. 'iz4 diff {$when.words[0]}~1 {$when.words[0]}' shows what it said.\n";
    }
    "PROMISE $id was withdrawn; its name is retired and never reused. 'iz4 log' shows when, where there is Git history.\n";
}

# ------------------------------------------------------------- withdraw

#| Take one of the project's own promises out of the file: its card (in
#| the earlier named form, its INVARIANT block and its BECAUSE) and the
#| blank line before it.  Nothing else is touched, Git keeps the words,
#| and the name is retired: it is never given to a different promise.
#| The tests that exist only for it go with it (withdrawal-tests,
#| remove-tests): the caller does that, after asking.  The foundation
#| cannot be withdrawn by any project (binding.iz4.you).  Returns the
#| promise as it was.  The caller confirms with a person first: this
#| discards their words only on their say-so.
sub withdraw-invariant(IO::Path $path, Str $ref --> IZ4::Document::Invariant) is export {
    my $doc = IZ4::Document.load($path);
    my $id = resolve-identity($doc, $ref) // $ref;
    user-error("$id is part of the foundation: it binds every project and cannot be withdrawn by one (binding.iz4.you)")
        if is-foundation-id($id);
    my $inv = $doc.invariant($id);
    without $inv {
        with withdrawn-in($path, $id) -> $when { user-error("PROMISE $id was already withdrawn in commit $when") }
        user-error("PROMISE $id was already withdrawn") if $doc.retired.first(* eq $id).defined;
        user-error("no invariant '$ref' in {$path.basename}; 'iz4 show invariants' lists its own");
    }
    my @lines = $doc.lines;
    my $from  = $inv.line - 1;
    my $to    = ($doc.form eq 'clauses' || $doc.form eq 'card' ?? $inv.last-line !! $inv.because-line.defined
        ?? ($doc.blocks.first({ .kind eq 'BECAUSE' && .line == $inv.because-line }).last-line)
        !! $inv.last-line) - 1;
    # One comment line stands where it was, so every reader sees that the
    # promise existed, and so the name stays retired even where there is
    # no Git history to consult.
    @lines.splice($from, $to - $from + 1, withdrawn-comment($id, :heading($doc.form eq 'card' ?? 'PROMISE' !! 'INVARIANT')));
    @lines.pop while @lines && @lines[*-1].trim eq '';
    $path.spurt(@lines.join("\n") ~ "\n");
    $inv;
}

#| The comment left where a withdrawn promise stood: its heading word as
#| the file writes it (PROMISE on a card, INVARIANT in the earlier forms).
sub withdrawn-comment(Str $id, Str :$heading = 'INVARIANT' --> Str) { "# $heading $id was withdrawn on {Date.today}; its name is retired." }

#| The names a file's own comments say were withdrawn.
sub withdrawn-in-text(IO::Path $path --> List) is export { IZ4::Document.load($path).retired.List }

#| The commit in which invariant $id left the file, as 'HASH (DATE)', or
#| Str when Git does not show one.
sub withdrawn-in(IO::Path $path, Str $id --> Str) is export {
    my ($rc, $log, $) = git($path, 'log', '-p', '--follow', '--date=short', '--format=%x01%h %ad', '--', $path.basename);
    return Str if $rc != 0;
    for $log.split("\x01").grep(* ne '') -> $commit {
        my ($head, @body) = $commit.lines;
        # the heading as it was written then: PROMISE on a card, INVARIANT in the earlier forms
        my $gone = @body.first({ .trim-trailing eq "-PROMISE $id" || .trim-trailing eq "-INVARIANT $id" }).defined;
        my $back = @body.first({ .trim-trailing eq "+PROMISE $id" || .trim-trailing eq "+INVARIANT $id" }).defined;
        return "{$head.words[0]} ({$head.words[1]})" if $gone && !$back;
    }
    Str;
}

#| Test files that name invariant $id, relative to $root: after a
#| withdrawal they are the next thing to look at.
sub tests-naming(IO::Path $root, Str $id --> List) is export {
    test-files($root).grep({ (try .slurp) andthen names-identity($_, $id) }).map(*.relative($root)).List;
}

#| What withdrawing invariant $id means for the tests that name it,
#| decided before anything is touched.  $doc is the document as it is
#| now, with the invariant still in it.  A hash of three lists:
#|
#|   remove   test files that exist only for this invariant, and that Git
#|            holds exactly as they are: taking them out loses nothing
#|   shared   (file, the other invariants it also names): left in place,
#|            because they still protect something
#|   unsaved  files Git does not hold as they are (untracked, or changed
#|            since the last commit): left in place, because removing
#|            them would discard work for good
#|
#| A test for an invariant that no longer exists protects nothing, and a
#| scaffold for it would fail for ever, so the first list goes with the
#| invariant.  Nothing here deletes: remove-tests does, on a person's yes.
sub withdrawal-tests(IO::Path $path, IZ4::Document $doc, Str $id --> Hash) is export {
    my $root = $path.parent;
    my @others = $doc.invariants.map(*.id).grep({ .defined && $_ ne $id });
    my (@remove, @shared, @unsaved);
    for tests-naming($root, $id) -> $rel {
        my $text = (try $root.add($rel).slurp) // '';
        my @also = @others.grep({ names-identity($text, $_) });
        if @also { @shared.push: ($rel.Str, @also.List); next }
        my ($tracked) = git($path, 'ls-files', '--error-unmatch', '--', $rel.Str);
        my ($rc, $changed, $) = git($path, 'status', '--porcelain', '--', $rel.Str);
        if $tracked == 0 && $rc == 0 && $changed.trim eq '' { @remove.push($rel.Str) }
        else { @unsaved.push($rel.Str) }
    }
    %( remove => @remove, shared => @shared, unsaved => @unsaved );
}

#| Take test files out.  Returns the ones removed.
sub remove-tests(IO::Path $root, @files --> List) is export {
    my @gone;
    for @files -> $rel {
        my $f = $root.add($rel);
        next unless $f.e && $f.f;
        $f.unlink;
        @gone.push($rel);
    }
    @gone.List;
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
    if $doc.form eq 'clauses' || $doc.form eq 'card' {
        my @clauses-new = purpose-lines("$which?", $value);
        with $doc.blocks.first(*.kind eq $which) -> $b {
            user-error("$which is already set; use --replace to replace it") if $b.text ne '' && !$replace;
            @lines.splice($b.line - 1, $b.last-line - $b.line + 1, @clauses-new);
        }
        else {
            my $after = ($which eq 'IS FOR WHO' ?? ($doc.blocks.first(*.kind eq 'IS FOR WHAT') andthen .last-line) !! Int) // ($doc.header-line // 0);
            @lines.splice($after, 0, |@clauses-new);
        }
        $path.spurt(@lines.join("\n") ~ "\n");
        return $which;
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

#| Every name this file has ever given an invariant: from its Git history
#| as well as its current text and its 'was withdrawn' comments, so a
#| retired name is never handed to a different invariant.  Without Git,
#| or for an untracked file, only the current text is known.
sub names-ever-used(IO::Path $path --> List) is export {
    my $doc = IZ4::Document.load($path);
    my @names = |$doc.invariants.map(*.id).grep(*.defined), |$doc.retired;
    my ($rc, $log, $) = git($path, 'log', '-p', '--follow', '--format=', '--', $path.basename);
    if $rc == 0 {
        for $log.lines -> $l {
            # a card's PROMISE heading, or the earlier forms' INVARIANT heading
            @names.push(~$0) if $l ~~ /^ <[+\-]> [ 'PROMISE' || 'INVARIANT' ] \h+ (\S+) \h* $/ && !numbered-label(~$0);
            # the earlier clauses form: a name and a colon, made whole under
            # the file's domain
            if $l ~~ /^ <[+\-]> (<[a..z 0..9]> <[\w.\-]>*) ':' \h* $/ {
                my $n = ~$0;
                @names.push($doc.domain.defined ?? clauses-identity($n, $doc.domain) !! $n);
            }
        }
    }
    @names.unique.List;
}

#| The namespace a new invariant's name goes under: the one the file's
#| own invariants already share, else the one given, else IZ4_NAMESPACE.
#| Str when none of those says: the caller asks a person, once.
sub project-namespace(IO::Path $path, Str :$given --> Str) is export {
    my $ns = ($given // '').trim.lc || IZ4::Document.load($path).namespace || (%*ENV<IZ4_NAMESPACE> // '').trim.lc;
    $ns ?? $ns !! Str;
}

#| Why a string cannot be a namespace, or ''.
sub namespace-problem(Str $ns --> Str) is export {
    my $why = identity-problem("x.$ns");
    return $why if $why;
    # iz4.you may be a project's own domain; its invariants then need an area label, which check-new-name sees to
    '';
}

#| A namespace to offer when nothing says: the directory's own name, when
#| it reads as a domain (cli.iz4.you, honeywillow.com).  A suggestion
#| only; a person confirms it.
sub suggested-namespace(IO::Path $path --> Str) is export {
    my $dir = $path.resolve.parent.basename.lc;
    $dir.contains('.') && namespace-problem($dir) eq '' ?? $dir !! Str;
}

#| The full identity for a name a person typed: as given when it is
#| already a whole name, else under $namespace.
sub full-identity(Str $name, Str $namespace? --> Str) is export {
    my $n = $name.trim;
    return $n if is-identity($n) || !$namespace;
    "$n.$namespace";
}

#| Refuse a name no new invariant in $path may take.
sub check-new-name(IO::Path $path, IZ4::Document $doc, Str $id) is export {
    with identity-problem($id) -> $why {
        user-error("'$id' is not a name an invariant can have: $why") if $why;
    }
    user-error("$id is part of the foundation: every IZ4 carries it word for word, and it cannot be redefined")
        if is-foundation-id($id);
    user-error("'$id': names directly under {FOUNDATION-NAMESPACE} are the foundation's, which is the same in every IZ4; name yours under your project's own domain")
        if reserved-identity($id);
    my $h = $doc.form eq 'card' ?? 'PROMISE' !! 'INVARIANT';
    user-error("$h $id is already in {$path.basename}; a name belongs to one promise")
        if $doc.invariant($id).defined;
    user-error("$h $id was used before in {$path.basename} (see 'iz4 log'); a name is never reused for a different invariant, so choose a new one")
        if names-ever-used($path).first(* eq $id).defined;
}

#| Add one of the project's own promises under the name $name: $text is
#| its ALWAYS, :reach its WHEN and :because its PROTECTS; :established
#| says what its changes require.  The name is the full identity.  The
#| foundation's names, names in use and names the file has ever used are
#| refused.  Returns the name written.  Existing text is never touched:
#| the new card goes before the foundation, which is read last.  The
#| earlier forms, read only to migrate, still take a block of their own.
sub add-invariant(IO::Path $path, Str $text, Str :$name!, Str :$because, Str :$namespace, Str :$reach, Bool :$established = False --> Str) is export {
    my $value = $text.trim;
    user-error("nothing to add: the invariant is empty") if $value eq '';
    my $doc = IZ4::Document.load($path);
    check-new-name($path, $doc, $name);
    my $reason = ($because // '').trim;
    if $doc.form eq 'card' {
        my $r = ($reach // '').trim;
        user-error("a promise needs a WHEN: the situation it applies in (--when=\"a private profile can be seen by anyone but its owner\")") if $r eq '';
        user-error("a promise needs a PROTECTS: whose what would be lost if it stopped holding (--protects=\"a job seeker's current job\"). If nothing a person would lose comes to mind, this is probably a constraint for the README, not a promise") if $reason eq '';
        my @lines = $doc.lines;
        my @block = card-lines('PROMISE', $name, $r, ($value,), ($reason,), ($established ?? CHANGE-SIGNED !! CHANGE-FREE));
        # the project's own come before the foundation, which is read last
        my $at = @lines.first({ $_ eq FOUNDATION-RULE-OFF }, :k);
        $at //= do if $doc.foundation-spans {
            my $i = $doc.foundation-spans.map(*[0]).min - 1;
            $i-- while $i > 0 && @lines[$i - 1].starts-with('#');
            $i;
        }
        $at //= @lines.elems;
        $at-- while $at > 0 && @lines[$at - 1].trim eq '';
        @lines.splice($at, 0, ('', |@block));
        my $after = $at + 1 + @block.elems;
        @lines.splice($after, 1) while $after < @lines.elems && @lines[$after].trim eq '';
        @lines.splice($after, 0, '') if $after < @lines.elems;
        @lines.pop while @lines && @lines[*-1].trim eq '';
        my $was = $path.slurp;
        $path.spurt(@lines.join("\n") ~ "\n");
        written-as-meant($path, $name, :text($value), :because($reason), :reach($r), :$was);
        return $name;
    }
    if $doc.form eq 'clauses' {
        # the earlier clauses form, read only to migrate
        my $r = ($reach // '').trim;
        user-error("an invariant needs a WHERE: the situation it applies in (--where=\"a private profile can be seen by anyone but its owner\")") if $r eq '';
        user-error("an invariant needs a PROTECTS: whose what would be lost if it stopped holding (--protects=\"a job seeker's current job\"). If nothing a person would lose comes to mind, this is probably a constraint for the README, not an invariant") if $reason eq '';
        my @lines = $doc.lines;
        my @block = clauses-invariant-lines(clauses-short-name($doc, $name), $r, $value, $reason);
        # the project's own come before the foundation, which is read last
        my $at = @lines.first({ $_ eq FOUNDATION-RULE-OFF }, :k);
        $at //= do if $doc.foundation-spans {
            my $i = $doc.foundation-spans.map(*[0]).min - 1;
            $i-- while $i > 0 && @lines[$i - 1].starts-with('#');
            $i;
        }
        $at //= @lines.elems;
        $at-- while $at > 0 && @lines[$at - 1].trim eq '';
        @lines.splice($at, 0, ('', |@block));
        # one blank line between the new block and what follows it
        my $after = $at + 1 + @block.elems;
        @lines.splice($after, 1) while $after < @lines.elems && @lines[$after].trim eq '';
        @lines.splice($after, 0, '') if $after < @lines.elems;
        @lines.pop while @lines && @lines[*-1].trim eq '';
        my $was = $path.slurp;
        $path.spurt(@lines.join("\n") ~ "\n");
        written-as-meant($path, $name, :text($value), :because($reason), :reach($r), :$was);
        return $name;
    }

    # the earlier named form, read only to migrate
    my @lines = $doc.lines;
    @lines.pop while @lines && @lines[*-1].trim eq '';
    # the namespace, said once in the file, the first time one is chosen
    @lines.append: '', namespace-comment($namespace)
        if $namespace && $name.ends-with(".$namespace") && !$doc.namespace.defined;
    @lines.append: '', "INVARIANT $name", |wrap($value, WRAP-WIDTH);
    @lines.append: '', 'BECAUSE', |wrap($reason, WRAP-WIDTH) if $reason ne '';
    $path.spurt(@lines.join("\n") ~ "\n");
    $name;
}

#| How a project's own invariant is named in the earlier clauses form: its
#| name without the file's domain (area labels kept), else whole.
sub clauses-short-name(IZ4::Document $doc, Str $id --> Str) is export {
    my $d = $doc.domain // return $id;
    return $id unless $id.ends-with(".$d") && $id.chars > $d.chars + 1;
    $id.substr(0, $id.chars - $d.chars - 1);
}

#| After a write, the words read back as they were meant, or the file goes
#| back to what it was: the tool never keeps a file that lost a word.
sub written-as-meant(IO::Path $path, Str $id, Str :$text!, Str :$because = '', Str :$reach, Str :$was!) {
    my $got = IZ4::Document.load($path).invariant($id);
    my $ok = $got.defined && normalised($got.text) eq normalised($text) && normalised($got.because // '') eq normalised($because)
        && (!$reach.defined || normalised($got.reach // '') eq normalised($reach));
    return if $ok;
    $path.spurt($was);
    user-error("$id would not read back word for word, so nothing was written; this is a bug in iz4, please report the words");
}

#| In the earlier named form, the one line that tells a reader, and the
#| next 'iz4 add', which domain this project's invariants are named
#| under.  A card file names its domain in the header instead.
sub namespace-comment(Str $namespace --> Str) is export { "# This project's invariants are named under $namespace." }

#| In the earlier named form only: name the unnamed INVARIANT block on
#| line $line.  Only its header line is touched.  A promise card always
#| carries its name, so there is nothing to name there.
sub name-invariant(IO::Path $path, Int $line, Str $name --> Str) is export {
    my $doc = IZ4::Document.load($path);
    user-error("every promise carries its name in its heading; there is nothing to name") if $doc.form eq 'clauses' | 'card';
    my $inv = $doc.invariants.first({ .line == $line })
        // user-error("no INVARIANT on line $line of {$path.basename}");
    user-error("the invariant on line $line is already named {$inv.id}; a name is an identity and is not changed (withdraw it and add a new one if it is a different commitment)")
        if $inv.id.defined;
    check-new-name($path, $doc, $name);
    my @lines = $doc.lines;
    @lines[$line - 1] = "INVARIANT $name";
    $path.spurt(@lines.join("\n") ~ "\n");
    $name;
}

# --------------------------------------------------------------- protects

#| Set the PROTECTS of one of the project's own promises (its BECAUSE in
#| the earlier forms).  An existing one needs :replace.  Returns its name.
sub set-because(IO::Path $path, Str $ref, Str $text, Bool :$replace = False --> Str) is export {
    my $reason = $text.trim;
    user-error('nothing to set: the reason is empty') if $reason eq '';
    my $doc = IZ4::Document.load($path);
    my $inv = invariant-or-die($doc, $path, $ref);
    user-error("PROMISE {$inv.id} already has a PROTECTS; use --replace to replace it")
        if ($inv.because // '').trim && !$replace;
    rewrite-invariant($path, $doc, $inv, $inv.text, $reason);
    $inv.id;
}

#| Move the reason folded into a promise's own words under PROTECTS (its
#| BECAUSE in the earlier forms).  Returns the reason moved, or Str when
#| none was found.  The words are the owner's, only moved; nothing is added.
sub split-because(IO::Path $path, Str $ref --> Str) is export {
    my $doc = IZ4::Document.load($path);
    my $inv = invariant-or-die($doc, $path, $ref);
    user-error("PROMISE {$inv.id} already has a PROTECTS") if ($inv.because // '').trim;
    my ($claim, $reason) = split-reason($inv.text);
    return Str without $reason;
    rewrite-invariant($path, $doc, $inv, $claim, $reason);
    $reason;
}

#| Every invariant without a PROTECTS whose own words hold one: split
#| them all.
#| Returns (name, reason) pairs.
sub split-all-because(IO::Path $path --> List) is export {
    my @done;
    for IZ4::Document.load($path).unexplained-invariants.map(*.id).grep(*.defined) -> $id {
        with split-because($path, $id) -> $reason { @done.push: ($id, $reason) }
    }
    @done;
}

sub invariant-or-die(IZ4::Document $doc, IO::Path $path, Str $ref) {
    my $id = resolve-identity($doc, $ref) // $ref;
    user-error("$id is part of the foundation; its words are the same in every IZ4 and not yours to change") if is-foundation-id($id);
    $doc.invariant($id) // user-error("no invariant '$ref' in {$path.basename}; {own-names($doc)}");
}

#| Give one promise new words: its ALWAYS and PROTECTS on a card (the
#| INVARIANT block and its BECAUSE, if any, in the earlier forms).
#| Everything outside it is untouched.
sub rewrite-invariant(IO::Path $path, IZ4::Document $doc, $inv, Str $claim, Str $reason) {
    my @lines = $doc.lines;
    if $doc.form eq 'card' {
        # only ALWAYS and PROTECTS are replaced; the heading, WHEN and the governance stay as written
        my %part;
        for $doc.blocks.grep({ .line > $inv.line && .line <= $inv.last-line && .kind eq any(<ALWAYS PROTECTS>) }) { %part{.kind} //= $_ }
        user-error("{$inv.id} has no ALWAYS line to rewrite") unless %part<ALWAYS>.defined;
        my @edits;
        @edits.push: (%part<ALWAYS>.line, %part<ALWAYS>.last-line, card-field-lines('ALWAYS', ($claim,)));
        if $reason.trim ne '' {
            @edits.push: %part<PROTECTS>.defined ?? (%part<PROTECTS>.line, %part<PROTECTS>.last-line, card-field-lines('PROTECTS', ($reason,)))
                                                 !! (%part<ALWAYS>.last-line + 1, %part<ALWAYS>.last-line, card-field-lines('PROTECTS', ($reason,)));
        }
        for @edits.sort({ -$_[0] }) -> ($from, $to, @new) { @lines.splice($from - 1, $to - $from + 1, @new) }
        my $was = $path.slurp;
        $path.spurt(@lines.join("\n") ~ "\n");
        written-as-meant($path, $inv.id, :text($claim), :because($reason.trim), :$was);
        return;
    }
    if $doc.form eq 'clauses' {
        # the earlier clauses form: only ALWAYS and PROTECTS are replaced;
        # the name and WHERE stay as written
        my %part;
        for $doc.blocks.grep({ .line > $inv.line && .line <= $inv.last-line && .kind eq any(<WHERE ALWAYS PROTECTS>) }) { %part{.kind} //= $_ }
        my @edits;
        @edits.push: (%part<ALWAYS>.line,   %part<ALWAYS>.last-line,   clause-lines('ALWAYS', $claim)) if %part<ALWAYS>.defined;
        if $reason.trim ne '' {
            @edits.push: %part<PROTECTS>.defined ?? (%part<PROTECTS>.line, %part<PROTECTS>.last-line, clause-lines('PROTECTS', $reason))
                                                 !! ($inv.last-line + 1, $inv.last-line, clause-lines('PROTECTS', $reason));
        }
        elsif %part<PROTECTS>.defined { @edits.push: (%part<PROTECTS>.line, %part<PROTECTS>.last-line, ()) }
        for @edits.sort({ -$_[0] }) -> ($from, $to, @new) { @lines.splice($from - 1, $to - $from + 1, @new) }
        my $was = $path.slurp;
        $path.spurt(@lines.join("\n") ~ "\n");
        written-as-meant($path, $inv.id, :text($claim), :because($reason.trim), :$was);
        return;
    }
    # the earlier named form: the whole block and its BECAUSE are rewritten
    my $from  = $inv.line - 1;
    my $to    = ($inv.because-line.defined
        ?? ($doc.blocks.first({ .kind eq 'BECAUSE' && .line == $inv.because-line }).last-line)
        !! $inv.last-line) - 1;
    my @new = "INVARIANT {$inv.id}", |wrap($claim, WRAP-WIDTH);
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

# ------------------------------------------------------------------- when

#| Set the WHEN of one of the project's own promises (its WHERE in the
#| earlier clauses form).  Returns its name.
sub set-reach(IO::Path $path, Str $ref, Str $text --> Str) is export {
    my $reach = $text.trim;
    user-error('nothing to set: the WHEN is empty') if $reach eq '';
    my $doc = IZ4::Document.load($path);
    user-error("{$path.basename} is in the named form, which has no WHEN ('iz4 migrate' moves it to promise cards)") unless $doc.form eq 'clauses' | 'card';
    my $inv = invariant-or-die($doc, $path, $ref);
    my @lines = $doc.lines;
    if $doc.form eq 'card' {
        my $part = $doc.blocks.first({ .kind eq 'WHEN' && .line > $inv.line && .line <= $inv.last-line });
        if $part { @lines.splice($part.line - 1, $part.last-line - $part.line + 1, card-field-lines('WHEN', ($reach,))) }
        else     { @lines.splice($inv.line + 1, 0, card-field-lines('WHEN', ($reach,))) }
        my $was = $path.slurp;
        $path.spurt(@lines.join("\n") ~ "\n");
        written-as-meant($path, $inv.id, :text($inv.text), :because($inv.because // ''), :$reach, :$was);
        return $inv.id;
    }
    # the earlier clauses form
    my $part = $doc.blocks.first({ .kind eq 'WHERE' && .line > $inv.line && .line <= $inv.last-line });
    if $part { @lines.splice($part.line - 1, $part.last-line - $part.line + 1, clause-lines('WHERE', $reach)) }
    else     { @lines.splice($inv.line, 0, clause-lines('WHERE', $reach)) }
    my $was = $path.slurp;
    $path.spurt(@lines.join("\n") ~ "\n");
    written-as-meant($path, $inv.id, :text($inv.text), :because($inv.because // ''), :$reach, :$was);
    $inv.id;
}

# ---------------------------------------------------------------- migrate

#| What moving an IZ4 in the earlier named form to the earlier clauses
#| form would do, the first step on its way to cards, without doing it:
#|   needed  whether there is anything to move
#|   stop    why it cannot be done as the file stands ('' when it can)
#|   domain  the namespace the header will name, or Str when nothing says
#|   own     the project's own invariants, each { id, text, because }
sub clauses-migration-plan(IO::Path $path --> Hash) is export {
    my $doc = IZ4::Document.load($path);
    return %( :!needed, stop => '', own => [], domain => Str ) if $doc.form eq 'clauses';
    my $stop = $doc.errors ?? "the file has problems to settle first: {$doc.errors[0].message} (line {$doc.errors[0].line})" !! '';
    %( :needed, :$stop, domain => $doc.namespace,
       own => $doc.invariants.map({ %( id => .id, text => .text, because => .because ) }).Array );
}

#| Move an IZ4 in the earlier named form to the earlier clauses form, the
#| step before migrate-card takes it to cards.  %reach gives every project
#| invariant's WHERE (its WHEN on the card to come) by its full identity:
#| a person's to say, never made up here.  What changes: the header names
#| the domain, the two questions take their answers on the line, each of
#| the project's own invariants is laid out in that form's three clauses
#| with its ALWAYS and PROTECTS word for word, and the foundation is that
#| form's foundation, written last.  The result is read back before it is
#| written, and a file that would not check is never written.  Returns
#| the identities moved.
sub migrate-clauses(IO::Path $path, %reach, Str :$namespace --> List) is export {
    my %plan = clauses-migration-plan($path);
    user-error("{$path.basename} is already in the clauses form; there is nothing to migrate") unless %plan<needed>;
    user-error("cannot migrate {$path.basename}: %plan<stop>") if %plan<stop>;
    my $domain = ($namespace // %plan<domain> // '').trim.lc;
    user-error("from here on the header names the project's domain, as a card file does: pass --namespace=your.domain") if $domain eq '';
    with namespace-problem($domain) -> $why { user-error("'$domain' cannot be this project's domain: $why") if $why }
    my $doc = IZ4::Document.load($path);
    for $doc.invariants -> $inv {
        my $r = (%reach{$inv.id} // '').trim;
        user-error("{$inv.id} has no WHEN yet: the situation it applies in. A person says; it is never made up") if $r eq '';
        user-error("{$inv.id} has no PROTECTS: whose what would be lost if it stopped holding. A person says; it is never made up ('iz4 protects {$inv.id} WHAT' in the named file first)") if ($inv.because // '').trim eq '';
    }
    my $drop = "\x[0]drop";
    my @lines = $doc.lines;
    my sub replace-span(Int $from, Int $to, @new) {
        @lines[$from - 1] = @new.join("\n");
        @lines[$_ - 1] = $drop for $from + 1 .. $to;
    }
    @lines[$doc.header-line - 1] = "{ROOT-NAME} $domain";
    for @lines.kv -> $i, $l { @lines[$i] = $drop if $l ~~ /^ '#' \s* "This project's invariants are named under " / }
    for 'IS FOR WHAT', 'IS FOR WHO' -> $kind {
        my $b = $doc.blocks.first(*.kind eq $kind) // next;
        replace-span($b.line, $b.last-line, purpose-lines("$kind?", $b.text));
    }
    for $doc.invariants -> $inv {
        my $to = $inv.because-line.defined
            ?? $doc.blocks.first({ .kind eq 'BECAUSE' && .line == $inv.because-line }).last-line !! $inv.last-line;
        my $short = $inv.id.ends-with(".$domain") ?? $inv.id.substr(0, $inv.id.chars - $domain.chars - 1) !! $inv.id;
        replace-span($inv.line, $to, clauses-invariant-lines($short, %reach{$inv.id}.trim, $inv.text, $inv.because // ''));
    }
    my @out = with-foundation($doc, @lines, :to-clauses, :last).join("\n").lines.grep(* ne $drop);
    my $new = @out.join("\n") ~ "\n";
    my $check = IZ4::Document.parse($new);
    for $doc.invariants -> $inv {
        my $got = $check.invariant($inv.id);
        user-error("the clauses form of {$path.basename} would not carry {$inv.id} word for word; nothing was written")
            unless $got.defined && normalised($got.text) eq normalised($inv.text) && normalised($got.because // '') eq normalised($inv.because // '')
                && normalised($got.reach // '') eq normalised(%reach{$inv.id});
    }
    user-error("the clauses form of {$path.basename} would not check ({$check.errors[0].message}, line {$check.errors[0].line}); nothing was written")
        unless $check.ok;
    $path.spurt($new);
    $doc.invariants.map(*.id).List;
}

#| What moving an IZ4 in the earlier clauses form to promise cards would
#| do, without doing it: each of the project's own invariants with the
#| stage it will carry, read from that form's mode line and the word
#| after its name.
#|   needed   whether there is anything to move
#|   stop     why it cannot be done as the file stands ('' when it can)
#|   own      the project's own invariants, each { id, stage, was }
#|   notes    what changes in meaning, for a person to read first
sub card-migration-plan(IO::Path $path --> Hash) is export {
    my $doc = IZ4::Document.load($path);
    return %( :!needed, stop => '', own => [], notes => [] ) if $doc.form eq 'card';
    return %( :needed, stop => "{$path.basename} is in the earlier named form: 'iz4 migrate' moves it through the clauses form first, then to cards", own => [], notes => [] ) if $doc.form eq 'named';
    my $stop = $doc.errors ?? "the file has problems to settle first: {$doc.errors[0].message} (line {$doc.errors[0].line})" !! '';
    my @own = $doc.invariants.grep(*.id.defined).map({
        my $p = $doc.protection-of(.id);
        %( id => .id, stage => ($p eq 'vibe' ?? 'exploring' !! 'established'), was => ($p eq 'vibe' ?? 'vibe' !! $p) );
    });
    my @notes;
    @notes.push: "the mode line goes: what each promise's changes require is now written on its card" if $doc.mode ne 'solid';
    my @firm = @own.grep(*<was> eq 'firm');
    @notes.push: "{@firm.map(*<id>).join(', ')}: firm becomes established, so a failing linked test now holds the commit where before it was reported; 'iz4 explore NAME' if the tests are not ready" if @firm;
    @notes.push: "the foundation is written as five FOUNDATION cards: the same words, laid out as cards (sha256 {FOUNDATION-CARD-DIGEST.substr(0, 12)})";
    %( :needed, :$stop, :@own, :@notes );
}

#| Move an IZ4 in the earlier clauses form to promise cards.  Each of the
#| project's own invariants becomes a PROMISE card with its WHERE as WHEN,
#| its ALWAYS and PROTECTS word for word, and the governance that form's
#| protection gave it: vibe becomes exploring, firm and solid become
#| established.  Its mode line goes, the foundation is written as cards,
#| and nothing else is touched.  The result is read back before it is
#| written, and a file that would not check is never written.  Returns
#| the identities moved.
sub migrate-card(IO::Path $path --> List) is export {
    my %plan = card-migration-plan($path);
    user-error("{$path.basename} is already in the card form; there is nothing to migrate") unless %plan<needed>;
    user-error("cannot migrate {$path.basename}: %plan<stop>") if %plan<stop>;
    my $doc = IZ4::Document.load($path);
    my $drop = "\x[0]drop";
    my @lines = $doc.lines;
    my sub replace-span(Int $from, Int $to, @new) {
        @lines[$from - 1] = @new.join("\n");
        @lines[$_ - 1] = $drop for $from + 1 .. $to;
    }
    for @lines.kv -> $i, $l { @lines[$i] = $drop if $l ~~ /^ '#' \s* [ 'Vibe' | 'Firm' ] ':' / }
    for $doc.invariants.grep(*.id.defined) -> $inv {
        my $change = $doc.protection-of($inv.id) eq 'vibe' ?? CHANGE-FREE !! CHANGE-SIGNED;
        replace-span($inv.line, $inv.last-line, card-lines('PROMISE', $inv.id, $inv.reach // '', ($inv.text,), ($inv.because // '',), $change));
    }
    my @out = with-foundation($doc, @lines, :to-card).join("\n").lines.grep(* ne $drop);
    # one blank line between blocks, none doubled
    my @tidy;
    for @out -> $l { @tidy.push($l) unless $l eq '' && @tidy && @tidy.tail eq '' }
    my $new = @tidy.join("\n") ~ "\n";
    my $check = IZ4::Document.parse($new);
    for $doc.invariants.grep(*.id.defined) -> $inv {
        my $got = $check.invariant($inv.id);
        user-error("the card form of {$path.basename} would not carry {$inv.id} word for word; nothing was written")
            unless $got.defined && normalised($got.text) eq normalised($inv.text) && normalised($got.because // '') eq normalised($inv.because // '')
                && normalised($got.reach // '') eq normalised($inv.reach // '');
    }
    user-error("the card form of {$path.basename} would not check ({$check.errors[0].message}, line {$check.errors[0].line}); nothing was written")
        unless $check.ok;
    $path.spurt($new);
    $doc.invariants.grep(*.id.defined).map(*.id).List;
}

# ---------------------------------------------------------------- suggest

#| How long a drafted line may be, in words.  An IZ4 is read before every
#| change; a line longer than this is skimmed, and a skimmed invariant is
#| a lost one.  The budget is for drafts only: a person's own words are
#| theirs to keep at any length.
constant DRAFT-WORDS is export = 25;
constant DRAFT-BECAUSE-WORDS is export = 20;
constant DRAFT-REACH-WORDS is export = 15;

#| How many words a draft runs to.
sub draft-words(Str $text --> Int) is export { $text.words.elems }

#| True when a draft is longer than a person will read.
sub too-long(Str $text, Int $limit = DRAFT-WORDS --> Bool) is export { draft-words($text) > $limit }

#| What every drafting prompt says about length.
sub brevity-rule(--> Str) is export {
    qq:to/END/;
    Be brief.  An IZ4 is not a specification: it is read before every
    change, and a long line is skimmed.  Each invariant is one plain
    sentence of at most {DRAFT-WORDS} words, and each reason at most {DRAFT-BECAUSE-WORDS}.  State the
    one promise and stop: no lists, exceptions, examples or mechanisms.
    If it needs an 'and', it is probably two invariants; give the stronger.
    Too long: 'Customer payment details, including card numbers, expiry
    dates and billing addresses, are never written to logs, caches,
    analytics events or error reports in any environment.'
    Right: 'Payment details never leave the payment system.'
    END
}

#| The prompt that asks for drafts to be said again, shorter.  Each item
#| is a pair of the words and the most they may run to.
sub shorten-prompt(@items --> Str) is export {
    my $list = @items.kv.map(-> $i, $item { "{$i + 1} (at most {$item[1]} words): {$item[0]}" }).join("\n");
    qq:to/END/ ~ $list ~ "\n";
    These lines were drafted for a system's IZ4 file, which holds the few
    things that must stay true of it.  They are too long.  An IZ4 is not
    a specification: a long line is skimmed, and a skimmed invariant is
    a lost one.

    Say each again in one plain sentence within its limit.  Keep the one
    promise that matters most and drop lists, exceptions, examples and
    mechanisms.  Where a line holds two promises, keep the stronger.
    Never add anything that was not there.

    Reply with one line for each and nothing else, in exactly this form:
    1: <the shorter words>

    The lines:
    END
}

#| The shorter words out of a reply, by their number.  A line that is
#| missing, empty or still too long is left out, so the caller keeps
#| what it had.
sub parse-shorter(Str $reply, @items --> Hash) is export {
    my %out;
    for $reply.lines -> $line {
        next unless $line ~~ / ^ \h* (\d+) \h* <[:.)]> \h* (\N+) /;
        my ($n, $text) = +$0, (~$1).trim;
        next unless 1 <= $n <= +@items && $text ne '';
        next if too-long($text, @items[$n - 1][1]);
        %out{$n - 1} = $text;
    }
    %out;
}

#| The prompt for a first draft of what a system is for and who it is
#| for, read off the repository.  The reply is two lines.
sub purpose-prompt(Str :$evidence = '' --> Str) is export {
    q:to/END/ ~ $evidence ~ "\n";
    You are helping a developer write the first two lines of the IZ4 file
    for the system in this repository.  IZ4 means Is For.

    Read the evidence below and answer two questions in plain words, one
    sentence each, as the people who own this would say it.  Say what it
    is for, not how it is built: no frameworks, languages or file names.
    If you cannot tell, say what you can and keep it short.  Each answer
    is at most 20 words: a person reads these two lines before every
    change, so they must take a breath to read, not a minute.

    Reply with exactly two lines and nothing else:
    FOR WHAT: <what this system is for>
    FOR WHO: <who it is for>

    Evidence from the codebase:
    END
}

#| The two answers out of a reply, or an empty hash when either is missing.
sub parse-purpose(Str $reply --> Hash) is export {
    my $what = ($reply ~~ / ^^ \h* 'FOR WHAT:' \h* (\N+) /) ?? ~$0 !! '';
    my $who  = ($reply ~~ / ^^ \h* 'FOR WHO:'  \h* (\N+) /) ?? ~$0 !! '';
    $what.trim ne '' && $who.trim ne '' ?? %( for-what => $what.trim, for-who => $who.trim ) !! %();
}

#| The prompt for new words for an invariant that the software no longer
#| keeps: what is true of the software now, said as an invariant.
sub reword-prompt(Str :$id!, Str :$text!, Str :$because = '', Str :$failure = '', Str :$evidence = '' --> Str) is export {
    qq:to/END/ ~ $evidence ~ "\n";
    A system's IZ4 file holds the few things that must stay true of it.
    One of them no longer matches the software, and its owner has decided
    the software is right and the words are out of date.

    PROMISE $id
      ALWAYS    $text
      PROTECTS  {$because || '(nothing said)'}

    What its test reported:
    {$failure || '(nothing)'}

    Write the promise again so that it says what is true of the software
    now, keeping as much of the original as still holds.  One
    plain sentence of at most {DRAFT-WORDS} words, and no longer than the original
    unless it must be.  No implementation detail, lists or exceptions: an
    IZ4 is not a specification.  If you cannot tell what is true now, say
    so instead.

    Reply with exactly one line and nothing else:
    INVARIANT: <the new words>
    or
    CANNOT: <why not>

    Evidence from the codebase:
    END
}

#| The new words out of a reply, or Str.
sub parse-reword(Str $reply --> Str) is export {
    ($reply ~~ / ^^ \h* 'INVARIANT:' \h* (\N+) /) ?? (~$0).trim !! Str;
}

#| Give an invariant new words, keeping its name and its reason.  The name
#| stays because the promise is the same one, brought up to date; Git
#| keeps the words it had.
sub revise-invariant(IO::Path $path, Str $ref, Str $text --> Str) is export {
    my $doc = check-doc($path);
    my $inv = invariant-or-die($doc, $path, $ref);
    user-error('an invariant needs words') if $text.trim eq '';
    rewrite-invariant($path, $doc, $inv, $text.trim, $inv.because // '');
    $inv.id;
}

#| The prompt for repository analysis.  Its job is to keep IZ4 small.
sub suggest-prompt(Str :$current = '', Str :$evidence = '' --> Str) is export {
    q:to/END/.subst('BREVITY-RULE', brevity-rule().chomp) ~ ($current.trim || '(none yet)') ~ "\n\nEvidence from the codebase:\n" ~ $evidence ~ "\n";
    You are helping a developer find the few enduring invariants of the
    system in this repository, for its IZ4 file.

    IZ4 means Is For.  An IZ4 answers three questions: what is this system
    for, who is it for, and what must remain true for it to keep serving
    them.  It is deliberately incomplete.

    Do not try to make IZ4 complete.  Try to make it small.

    Every IZ4 carries the foundation word for word: Invariant Zero, humans
    first, then do no harm, human agency, honesty and the binding.
    Do not restate it; propose only this project's own invariants.

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

    BREVITY-RULE
    Reply with one item per line and nothing else, in exactly this form:
    STRONG | what must remain true, in one short sentence | BECAUSE: why it must survive, shorter still | evidence
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
