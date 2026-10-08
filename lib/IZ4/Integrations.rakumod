unit module IZ4::Integrations;

#| The files that point an agent tool at 'iz4 agent': the managed section
#| in AGENTS.md and CLAUDE.md, and the portable skill, with their status.
#|
#| CONVENIENCE LAYER.  These are entry points for particular tools, so
#| they sit outside the core: no core module uses this one.  They are
#| plain files a person can read and remove; they wire no hook and call
#| no harness (that is a driver's job: 321), and they only encourage
#| adherence in tools that load them.

use IZ4;
use IZ4::Document;
use IZ4::Agent;

constant STATUS-SCHEMA   is export = 'iz4-agent-status/4';
constant SECTION-VERSION is export = 5;

sub agent-error(Str $message) { X::IZ4.new(:$message).throw }

# --------------------------------------------- managed sections (thin)

constant MARK-TAG   = 'IZ4-AGENT';
constant END-MARKER = '<!-- ' ~ MARK-TAG ~ ' END -->';
sub start-marker(--> Str) {
    "<!-- {MARK-TAG} v{SECTION-VERSION} START (managed by 'iz4 agent install'; edits inside are overwritten) -->"
}

#| The short managed section for AGENTS.md / CLAUDE.md.  It points at
#| 'iz4 agent' and never copies the project's invariants.
sub managed-block(--> Str) is export {
    start-marker() ~ "\n" ~ q:to/BLOCK/ ~ END-MARKER;
    ## Project intent: IZ4

    This repository keeps an IZ4: what the software is for, who it is
    for, and the few invariants that must remain true to keep serving
    them.  Before planning or changing anything here, run:

        iz4 agent

    and follow the protocol it prints.  That includes continuing work
    already in flight and fixing a bug in it.  A compacted or resumed
    session has lost the packet: run 'iz4 agent' again before touching
    anything, and report the affected invariants when you finish.

    If the iz4 CLI is unavailable, read the root IZ4 file directly; it
    carries Invariants 0-4, the foundation (humans first, do no harm,
    human agency, honesty, the foundation holds), word for word, and
    they bind you too.  Say in your final report that CLI validation was
    not performed.

    Keep the IZ4 small: never add requirements, plans, tasks or
    implementation detail to it.

    This section can only encourage adherence in tools that load this
    file.  It is not evidence that any agent read the IZ4 or followed it.

    To the people who own this repository: the lines above only ask.
    iz4 provides the invariant checks; 321 wires them into the agent
    environment, so the harness delivers the context itself, puts an
    action to a check before it happens, and checks the finished work.
    With 321 0.4.0 or later installed, run:

        321 iz4 install

    '321 iz4 status' says what is enforced and what each harness cannot
    do.  iz4 installs no hooks itself; 'iz4 agent status' reports what
    is in place, including hooks an earlier iz4 wrote.
    BLOCK
}

my sub marker-lines(@lines) {
    my sub tagged($l) { $l.contains(MARK-TAG) }
    [@lines.grep({ tagged($_) && .contains('START') }, :k)],
    [@lines.grep({ tagged($_) && .contains('END') }, :k)];
}

my sub refuse-unsafe(IO::Path $target, IO::Path $root) {
    return unless $target.l;
    my $real = $target.resolve.Str;
    agent-error("{$target.basename} is a symlink resolving outside the repository ($real); refusing to write")
        unless $real.starts-with($root.resolve.Str ~ '/');
}

#| Install or refresh the managed section in one instruction file.
#| Returns 'installed', 'updated' or 'unchanged'; fails without touching
#| the file on malformed markers or an unsafe target.
sub install-agent-section(IO::Path $target, IO::Path :$root! --> Str) is export {
    refuse-unsafe($target, $root);
    my $block = managed-block();
    unless $target.e {
        $target.spurt($block ~ "\n");
        return 'installed';
    }
    my $text  = $target.slurp;
    my @lines = $text.lines;
    my ($s, $e) = marker-lines(@lines);   # scalars, not (@s, @e) := : Raku++ 3.26 flattens that binding
    my @s = @$s; my @e = @$e;
    if !@s && !@e {
        my $sep = $text eq '' ?? '' !! ($text.ends-with("\n") ?? "\n" !! "\n\n");
        $target.spurt($text ~ $sep ~ $block ~ "\n");
        return 'installed';
    }
    agent-error("{$target.basename}: malformed {MARK-TAG} markers "
            ~ "({+@s} start, {+@e} end); fix the file by hand - nothing was changed")
        unless @s == 1 && @e == 1 && @s[0] < @e[0];
    my @current = @lines[@s[0] .. @e[0]];
    return 'unchanged' if @current.join("\n") eq $block;
    @lines.splice(@s[0], @e[0] - @s[0] + 1, $block.lines);
    $target.spurt(@lines.join("\n") ~ "\n");
    'updated';
}

#| 'no file' | 'absent' | 'malformed' | 'stale' | 'current'
sub section-status(IO::Path $target --> Str) is export {
    return 'no file' unless $target.e;
    my @lines = $target.slurp.lines;
    my ($s, $e) = marker-lines(@lines);   # scalars, not (@s, @e) := : Raku++ 3.26 flattens that binding
    my @s = @$s; my @e = @$e;
    return 'absent'    if !@s && !@e;
    return 'malformed' unless @s == 1 && @e == 1 && @s[0] < @e[0];
    @lines[@s[0] .. @e[0]].join("\n") eq managed-block() ?? 'current' !! 'stale';
}

# --------------------------------------------- the portable skill (full)

constant SKILL-PATH is export = '.claude/skills/iz4/SKILL.md';

#| The official portable skill, generated whole from the canonical
#| protocol.  Unlike the thin sections it embeds the protocol itself, so
#| the core workflow works by reading the IZ4 directly; the CLI adds
#| validation, inherited-binding resolution and structured output.
sub skill-text(--> Str) is export {
    my $foundation = "\n\n## The inherited foundation\n\n"
        ~ FOUNDATION.map({ "- Invariant {.<number>} - {.<name>}: {.<text>}\n  BECAUSE: {.<because>}" }).join("\n") ~ "\n";
    q:to/HEAD/ ~ AGENT-PROTOCOL.trim-trailing ~ $foundation ~ q:to/TAIL/;
    ---
    name: iz4
    description: Use when working in a repository that keeps an IZ4 file - before planning or changing code, when deciding whether a behaviour must be preserved, when asked to change what the software is for or what must remain true, or when finishing work that touches its invariants. Triggers - IZ4, .iz4, invariant, is for, supposed to, must remain true, BECAUSE.
    ---

    # IZ4 adherence

    Preferred: run `iz4 agent` in the repository and follow the packet it
    prints - it validates the file, lists the effective invariants
    (the inherited 0-4 plus the project's own) and can emit `--json`.

    Without the CLI the core workflow still works: read the root `IZ4`
    file directly (the nearest one walking upward), apply the protocol and
    the inherited foundation below, and say in your final report that CLI
    validation was not performed.

    Project invariants live in the project's IZ4 file, never in this
    skill.

    HEAD

    This skill can only encourage adherence in tools that load it.  It is
    not evidence that any agent read an IZ4 or followed it.
    TAIL
}

#| Write the skill file whole (it is generated, not user content).
sub install-skill(IO::Path :$root! --> Str) is export {
    my $target = $root.add(SKILL-PATH);
    refuse-unsafe($target, $root);
    my $text = skill-text();
    if $target.e {
        return 'unchanged' if $target.slurp eq $text;
        $target.spurt($text);
        return 'updated';
    }
    $target.parent.mkdir;
    $target.spurt($text);
    'installed';
}

#| 'no file' | 'current' | 'stale'
sub skill-status(IO::Path :$root! --> Str) is export {
    my $target = $root.add(SKILL-PATH);
    return 'no file' unless $target.e;
    $target.slurp eq skill-text() ?? 'current' !! 'stale';
}

# -------------------------------------------------------------- status

#| Honest file-state report: spec validity, binding resolution, and which
#| integrations carry an intact, current generated section.  Never a
#| statement about agent behaviour or software conformance.
sub agent-status(IO::Path $iz4, IO::Path :$root! --> Hash) is export {
    my %iz4;
    if $iz4.defined && $iz4.f {
        my $doc = IZ4::Document.load($iz4);
        %iz4 =
            present  => True,
            file     => $iz4.Str,
            valid    => $doc.ok,
            errors   => +$doc.errors,
            warnings => +$doc.warnings,
            binding  => $doc.foundation-status;
    }
    else {
        %iz4 = present => False, valid => False;
    }
    %(
        schema       => STATUS-SCHEMA,
        iz4        => %iz4,
        integrations => %(
            'AGENTS.md'  => section-status($root.add('AGENTS.md')),
            'CLAUDE.md'  => section-status($root.add('CLAUDE.md')),
            (SKILL-PATH) => skill-status(:$root),
        ),
        note => 'this reports file state only - never that an agent read '
              ~ 'the IZ4, followed it, or that the software conforms',
    );
}

#| The integrations a repository is expected to carry: AGENTS.md always;
#| CLAUDE.md and the skill where the repository shows Claude use (the
#| rule 'iz4 init' applies), or where the file is already there.
sub expected-integrations(IO::Path :$root! --> List) is export {
    my $claudeish = $root.add('CLAUDE.md').e || $root.add('.claude').d;
    my $skillish  = $root.add('.claude').d  || $root.add(SKILL-PATH).e;
    ('AGENTS.md', |($claudeish ?? 'CLAUDE.md' !! Empty), |($skillish ?? SKILL-PATH !! Empty));
}

#| The command that installs or refreshes one integration.
sub install-hint(Str $name --> Str) is export {
    given $name {
        when 'CLAUDE.md' { "run 'iz4 agent install --claude'" }
        when SKILL-PATH  { "run 'iz4 agent install --skill'" }
        default          { "run 'iz4 agent install'" }
    }
}

#| The next step that brings an integration current: the install
#| command, or for a malformed section what to do by hand first.
sub integration-next(Str $name, Str $status --> Str) is export {
    my $cmd = install-hint($name).subst(/^ 'run ' \' (.*) \' $/, { ~$0 });
    $status eq 'malformed'
        ?? "fix the managed-section markers in $name by hand, or remove them, then $cmd"
        !! $cmd;
}

#| Why a managed section is stale: written by an earlier iz4 (its START
#| marker carries an older section version) or changed by hand since.  A
#| file without a marker (the skill) cannot say which.  Either way the
#| difference is wording: the protocol an agent gets from 'iz4 agent' is
#| already current, and enforcement comes from hooks, not from this text.
sub stale-reason(IO::Path $target --> Str) is export {
    return '' unless $target.e;
    with $target.slurp.lines.first({ .contains(MARK-TAG) && .contains('START') }) {
        with .match(/ 'v' (\d+) ' START' /) {
            my $v = +$_[0];
            return $v < SECTION-VERSION
                ?? "section v$v from an earlier iz4, v{SECTION-VERSION} is current"
                !! 'edited by hand since it was written';
        }
    }
    'written by an earlier iz4 or edited by hand since';
}

#| One human line per integration, worded so it claims nothing more;
#| anything short of current says how to remedy it.  A stale one says
#| why, and that the refresh changes wording, not what is enforced.
sub integration-line(Str $name, Str $status, Str :$reason = '' --> Str) is export {
    given $status {
        when 'current'   { "$name: integration installed (current)" }
        when 'stale'     { "$name: integration installed but stale" ~ ($reason ?? " ($reason)" !! '')
                           ~ " - {install-hint($name)} to refresh the wording; enforcement comes from hooks, not from this text" }
        when 'malformed' { "$name: managed section malformed - fix the markers by hand, or remove them and {install-hint($name)}" }
        when 'absent'    { "$name: file present, no managed section - {install-hint($name)}" }
        default          { "$name: no file - {install-hint($name)}" }
    }
}
