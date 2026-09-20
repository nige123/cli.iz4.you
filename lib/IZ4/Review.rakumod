unit module IZ4::Review;

#| Reviewing a change against the invariants.
#|
#| Two layers.  The offline layer is deterministic and honest about how
#| little it knows: it reads the diff and says which invariants the change
#| TOUCHES, by the invariant's own words turning up in changed lines or
#| file names, and asks a person to look.  It never says a change keeps
#| or breaks anything.
#|
#| The agent layer, opt-in like 'iz4 suggest', hands the diff and the
#| effective invariants to the developer's own agent command and asks for
#| an assessment per invariant in the protocol's honesty vocabulary, plus
#| any candidate invariant the change reveals.  A candidate is only ever
#| shown; the coach adds it, and only on a person's yes.

use IZ4;
use IZ4::Document;
use IZ4::Git;

#| The five honesty levels, from the agent protocol.
constant @ASSESSMENTS is export =
    <mechanically-verified supported-by-evidence apparently-consistent uncertain conflicting>;

# ---------------------------------------------------------------- the diff

#| The change to review, as a unified diff.  @range is what a person
#| would give git diff: nothing (working tree against HEAD), one revision
#| (that commit), or A..B.  :$staged reviews the index.  Returns (diff,
#| description); dies through git-error when there is no repository.
sub change-diff(IO::Path $iz4, *@range, Bool :$staged = False --> List) is export {
    my ($rc, $out, $err);
    if $staged {
        ($rc, $out, $err) = git($iz4, 'diff', '--no-color', '--cached');
        return ($out, 'staged changes') if $rc == 0;
    }
    elsif !@range {
        ($rc, $out, $err) = git($iz4, 'diff', '--no-color', 'HEAD');
        return ($out, 'working tree against HEAD') if $rc == 0;
    }
    elsif @range == 1 && !@range[0].contains('..') {
        ($rc, $out, $err) = git($iz4, 'show', '--no-color', '--format=', @range[0]);
        return ($out, "commit {@range[0]}") if $rc == 0;
    }
    else {
        ($rc, $out, $err) = git($iz4, 'diff', '--no-color', |@range);
        return ($out, @range.join(' ')) if $rc == 0;
    }
    X::IZ4.new(message => $rc == 127 ?? $err.trim !! "git: {$err.trim.lines.head // 'diff failed'}").throw;
}

#| The commits about to be pushed: upstream..HEAD, or the last few when
#| the branch has no upstream yet.
sub push-range(IO::Path $iz4 --> Str) is export {
    my ($rc, $out, $) = git($iz4, 'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}');
    return "{$out.trim}..HEAD" if $rc == 0 && $out.trim;
    my ($rc2, $list, $) = git($iz4, 'rev-list', '--max-count=6', 'HEAD');
    my @hashes = $list.lines;
    @hashes > 1 ?? "{@hashes[*-1]}..HEAD" !! 'HEAD';
}

# ------------------------------------------------------------ offline layer

my constant STOPWORDS = set <
    a an the and or but of to for in on at by with from as is are was were be
    been being it its they them their this that these those there must should
    has have had do does did not no never always can cannot will would shall
    may might so because since why then than we our us you your he she his her
    him who whom which what when where how all any each every only just very
    also still stay stays remain remains true into onto over under after before
    without within about between through during while same other another one
    two more most some such both either neither own same person people someone
    anyone nobody something anything nothing ever once again here there where
    made make makes making take takes taken taking give gives given get gets
    got put puts use uses used using keep keeps kept let lets say says said
    see sees seen way ways thing things time times new old
>;

#| A word reduced to a rough stem, so 'prices' meets 'price' and
#| 'printed' meets 'printing'.
sub stem(Str $w --> Str) {
    my $s = $w.lc;
    if    $s ~~ / 'ies' $ / && $s.chars > 5              { $s = $s.subst(/ 'ies' $ /, 'y') }
    elsif $s ~~ / [s|x|z|ch|sh] 'es' $ / && $s.chars > 5 { $s = $s.subst(/ 'es' $ /, '') }
    elsif $s ~~ / <-[s]> 's' $ / && $s.chars > 4         { $s = $s.subst(/ 's' $ /, '') }
    for 'ing', 'ed', 'er' -> $suffix {
        if $s.chars - $suffix.chars >= 4 && $s.ends-with($suffix) {
            $s = $s.substr(0, $s.chars - $suffix.chars);
            $s = $s.chop if $s ~~ / (<[a..z]>) $0 $ /;      # stopped -> stop
            last;
        }
    }
    $s;
}

#| The words an invariant is about: its own nouns and verbs, stemmed,
#| without the grammar words that every sentence shares.
sub invariant-terms(Str $text --> Set) is export {
    $text.lc.comb(/ <[a..z0..9]> ** 4..* /).grep({ $_ ∉ STOPWORDS }).map(&stem).grep(*.chars >= 4).Set;
}

#| The changed lines and file names in a diff, as stemmed words.
sub diff-terms(Str $diff --> Hash) is export {
    my %where;   # term => set of "file" or "line"
    my $file = '';
    for $diff.lines -> $l {
        if $l ~~ /^ '+++ ' ['b/']? (.+) $/ {
            $file = ~$0;
            %where{$_}{'file'} = True for $file.lc.comb(/ <[a..z0..9]> ** 4..* /).map(&stem);
            next;
        }
        next if $l.starts-with('---') || $l.starts-with('+++') || $l.starts-with('@@') || $l.starts-with('diff ') || $l.starts-with('index ');
        next unless $l.starts-with('+') || $l.starts-with('-');
        %where{$_}{'line'} = True for $l.substr(1).lc.comb(/ <[a..z0..9]> ** 4..* /).grep({ $_ ∉ STOPWORDS }).map(&stem);
    }
    %where;
}

#| Which project invariants a change touches, by their own words turning
#| up in it.  Returns a list of hashes: number, text, because, terms
#| (the words that matched).  An invariant counts as touched when at
#| least two of its words appear, or one word that is rare enough to be
#| specific.  This is a pointer for a person, not a judgement.
sub touched-invariants(IZ4::Document $doc, Str $diff --> List) is export {
    my %in = diff-terms($diff);
    my @out;
    for $doc.invariants -> $inv {
        my $terms = invariant-terms($inv.text);
        my @hit = $terms.keys.grep({ %in{$_}:exists }).sort;
        my $specific = @hit.grep(*.chars >= 8);
        next unless @hit >= 2 || $specific;
        @out.push: %( number => $inv.number, text => $inv.text, because => $inv.because, terms => @hit );
    }
    @out;
}

#| The offline report, as lines.
sub offline-report(IZ4::Document $doc, Str $diff, Str :$what --> List) is export {
    my @touched = touched-invariants($doc, $diff);
    my $files = $diff.lines.grep(*.starts-with('+++ ')).elems;
    return ("Nothing to review: no change in $what.",) unless $diff.trim;
    my @out = "Reviewed $what: $files file{$files == 1 ?? '' !! 's'} changed, against Invariants 0-{top-number($doc)}.";
    if @touched {
        @out.push: "This change touches, by its own words, Invariant {@touched.map(*<number>).join(', ')}. Look at each before you push:";
        for @touched -> %t {
            @out.push: "  Invariant {%t<number>}: {short(%t<text>)}";
            @out.push: "    BECAUSE {short(%t<because>)}" if %t<because>;
            @out.push: "    matched: {%t<terms>.join(', ')}";
        }
    }
    else {
        @out.push: "No project invariant's own words appear in the change. That means little: read the change against 'iz4 invariants' if it is consequential.";
    }
    @out.push: "Offline: nothing here says the change keeps or breaks an invariant; only a person or a review can.";
    @out;
}

sub top-number(IZ4::Document $doc --> Int) {
    my @n = $doc.invariants.map(*.number).grep(*.defined);
    @n ?? max(FIRST-PROJECT-NUMBER - 1, |@n) !! FIRST-PROJECT-NUMBER - 1;
}

sub short(Str $s --> Str) { $s.chars > 110 ?? $s.substr(0, 107).trim-trailing ~ '...' !! $s }

# -------------------------------------------------------------- agent layer

#| The prompt for an agent review.  It asks for honest assessments in the
#| protocol's vocabulary, and for candidates only where the change
#| reveals enduring intent - fewer, stronger, none is fine.
sub review-prompt(Str :$effective!, Str :$diff!, Str :$what = 'this change' --> Str) is export {
    q:to/END/ ~ $effective.trim ~ "\n\n=== the change ($what) ===\n" ~ $diff.trim ~ "\n=== end of change ===\n";
    You are reviewing a change to a system that keeps an IZ4 file.  IZ4
    means Is For: it says what the system is for, who it is for, and the
    few invariants that must remain true to keep serving them.

    Do two things, and nothing else.

    1. For each invariant the change could affect, assess it.  Use exactly
       one of these words, and mean it:
         mechanically-verified  a test or check in the change proves it
         supported-by-evidence  the diff shows it is kept, and you can point at it
         apparently-consistent  nothing in the diff works against it
         uncertain              the diff does not show enough to say
         conflicting            the diff works against it, and you can point at it
       Cite the lines or files you relied on.  Say 'uncertain' rather than
       guess.  Do not list invariants the change plainly does not touch.

    2. Only if the change reveals enduring intent that the IZ4 does not yet
       state, propose it.  The golden test: if the whole system were
       rewritten tomorrow, would we regret not telling the people rebuilding
       it this?  A new behaviour, a passing test, a refactor or a setting is
       not an invariant.  Propose at most 2, classed STRONG or POSSIBLE.
       For each give a concise, accurate, understandable statement of what
       must remain true, a one-sentence BECAUSE saying why it matters to who
       or what the system is for, and the evidence that would show it holds
       (a test, a check, a review).  None is a fine answer.  Never invent
       intent: where it depends on the owner, class it POSSIBLE and say the
       question.

    Reply with one item per line and nothing else, in exactly this form:
    INVARIANT n | assessment | evidence, citing lines or files
    CANDIDATE | STRONG or POSSIBLE | what must remain true | BECAUSE: why | EVIDENCE: what would show it holds

    The IZ4, effective invariants:
    END
}

#| Read the agent's reply.  Unknown lines are ignored; candidates are
#| capped so a flood never reaches the person.
sub parse-review(Str $reply --> Hash) is export {
    my %r = assessments => [], candidates => [];
    for $reply.lines -> $raw {
        my $line = $raw.trim.subst(/^ <[\-*•]> \s* /, '');
        my @f = $line.split(/\s* '|' \s*/)».trim;
        next unless @f >= 2;
        if @f[0] ~~ /:i^ 'invariant' \s+ (\d+) $/ {
            my $number = +$0;
            my $level  = @f[1].lc.subst(/\s+/, '-', :g);
            next unless $level eq any(@ASSESSMENTS);
            %r<assessments>.push: %( :$number, level => $level, evidence => @f[2] // '' );
        }
        elsif @f[0] ~~ /:i^ 'candidate' $/ && @f >= 3 {
            my $class = @f[1].uc;
            next unless $class eq 'STRONG' | 'POSSIBLE';
            my %c = :$class, text => @f[2], because => '', evidence => '';
            for @f[3 .. *] -> $part {
                if    $part ~~ /:i^ 'because' ':'? \s* (.*) $/  { %c<because>  = ~$0 }
                elsif $part ~~ /:i^ 'evidence' ':'? \s* (.*) $/ { %c<evidence> = ~$0 }
            }
            %r<candidates>.push: %c;
        }
    }
    %r<candidates> = [%r<candidates>.head(2)];
    %r;
}

#| One agent pass over the change.  Dies when the agent fails.
sub agent-review(IO::Path $iz4, Str :$diff!, Str :$what!, Str :$cmd = agent-cmd() --> Hash) is export {
    my $doc = IZ4::Document.load($iz4);
    my $prompt = review-prompt(effective => effective-text($doc), :$diff, :$what);
    note "asking agent ($cmd) to review $what ...";
    my $proc = run '/bin/sh', '-c', $cmd, :in, :out;
    $proc.in.print($prompt);
    my $ = $proc.in.close;
    my $reply = $proc.out.slurp(:close);
    die "agent command failed ($cmd)" if $proc.exitcode != 0;
    parse-review($reply);
}

#| The agent's assessments as report lines, worded as opinions.
sub assessment-lines(%review, IZ4::Document $doc --> List) is export {
    my @out;
    unless %review<assessments> {
        @out.push: 'The agent named no invariant the change could affect.';
        return @out;
    }
    @out.push: "The agent's assessment (an opinion with evidence, not a proof):";
    for %review<assessments>.list -> %a {
        my $label = %a<number> < FIRST-PROJECT-NUMBER ?? "Invariant {%a<number>} (inherited)" !! "Invariant {%a<number>}";
        @out.push: sprintf('  %-26s %-22s %s', $label, %a<level>, %a<evidence>);
    }
    @out;
}

# ---------------------------------------------------------------- the hook

constant HOOK-MARK = '# iz4 review hook';

#| The advisory pre-push hook: reviews what is about to be pushed and
#| never blocks unless IZ4_REVIEW_STRICT is set.
sub hook-text(--> Str) is export {
    qq:to/END/;
    #!/bin/sh
    {HOOK-MARK} (written by 'iz4 review --install-hook'; delete this file to remove it)
    command -v iz4 >/dev/null 2>&1 || exit 0
    if [ -n "\$IZ4_REVIEW_STRICT" ]; then iz4 review --for-push --strict; else iz4 review --for-push; exit 0; fi
    END
}

#| Write the hook.  Refuses to replace a hook that is not ours unless
#| :force.  Returns 'installed', 'unchanged' or 'updated'.
sub install-hook(IO::Path $iz4, Bool :$force = False --> Str) is export {
    my ($rc, $out, $err) = git($iz4, 'rev-parse', '--git-path', 'hooks/pre-push');
    X::IZ4.new(message => 'not in a Git repository; a hook needs one').throw if $rc != 0;
    my $hook = $out.trim.IO;
    $hook = $iz4.parent.add($hook) unless $hook.is-absolute;
    my $text = hook-text();
    if $hook.e {
        my $current = $hook.slurp;
        return 'unchanged' if $current eq $text;
        X::IZ4.new(message => "{$hook} exists and is not the iz4 hook; pass --force to replace it, or call iz4 review --for-push from it").throw
            unless $current.contains(HOOK-MARK) || $force;
        $hook.spurt($text);
        $hook.chmod(0o755);
        return 'updated';
    }
    $hook.parent.mkdir;
    $hook.spurt($text);
    $hook.chmod(0o755);
    'installed';
}
