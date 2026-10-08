unit module IZ4::LegacyHook;

#| COMPATIBILITY ONLY, DEPRECATED.  The hook command iz4 shipped up to
#| 0.14: 'iz4 hook session-start | pre-edit | stop', and the reading of the
#| wiring those versions wrote into Claude Code's project settings.
#|
#| iz4 installs itself into no agent environment any more and holds no
#| harness knowledge in its core: a driver (321) does that, and calls the
#| machine interface (IZ4::Machine).  This module is what is left so that
#| repositories wired by an earlier iz4 keep exactly the enforcement they
#| had until a driver adopts the wiring ('321 iz4 install'): the old
#| commands still answer, and status can still say they are there.  It
#| reads one harness's event shape and settings file, which is why it is
#| kept apart: nothing in the core uses it, nothing new is ever wired to
#| it, and it goes once the transition is over.
#|
#| What the old commands do is unchanged: the packet is delivered at
#| session start, one edit made before it is refused, and one turn end
#| that changed files without the per-invariant report is refused.  None
#| of that proves an invariant was honoured.

use IZ4;
use IZ4::Document;
use IZ4::Agent;
use IZ4::Git;
use IZ4::Register;

#| Exit codes the harness contract uses: 0 allow, 2 refuse with the
#| reason on standard error.
constant ALLOW  is export = 0;
constant REFUSE is export = 2;

# ------------------------------------------------------------ session marks

#| Where a session's marks live: one file per session id, saying the
#| packet was delivered to it.
sub mark-dir(--> IO::Path) {
    my $base = %*ENV<XDG_CACHE_HOME> // %*ENV<HOME>.IO.add('.cache').Str;
    $base.IO.add('iz4').add('sessions');
}

sub session-id(%input --> Str) {
    (%input<session_id> // %*ENV<IZ4_SESSION> // 'no-session').Str.subst(/<-[\w.\-]>/, '_', :g);
}

sub mark(%input, Str $what) {
    my $dir = mark-dir();
    $dir.mkdir;
    $dir.add(session-id(%input) ~ ".$what").spurt(DateTime.now.Str ~ "\n");
}

sub marked(%input, Str $what --> Bool) {
    mark-dir().add(session-id(%input) ~ ".$what").e;
}

# ------------------------------------------------------------------ events

#| The harness's JSON, from standard input; an empty or unreadable input
#| is an empty hash, never an error, so a hook can run by hand.
sub read-input(Str $text --> Hash) is export {
    return %() unless $text.trim;
    my $parsed = try Rakudo::Internals::JSON.from-json($text);
    $parsed ~~ Associative ?? %$parsed !! %();
}

#| Session start (also resume and compaction): deliver the packet.
#| Returns (exit, stdout, stderr).
sub on-session-start(IO::Path $iz4, %input --> List) is export {
    my $packet = try packet-text(agent-packet($iz4));
    without $packet {
        return (ALLOW, '', "iz4: {$!.message.lines.head}\n");
    }
    mark(%input, 'packet');
    (ALLOW,
     "The IZ4 packet for this repository, loaded by the session-start hook. "
     ~ "Read it before planning or changing anything; it is delivered again after a compaction.\n\n"
     ~ $packet,
     '');
}

#| Before an edit or write: refuse once if the packet was never delivered
#| in this session, delivering it in the refusal so the next attempt
#| passes.  Files that hold no code or intent are let through.
sub on-pre-edit(IO::Path $iz4, %input --> List) is export {
    return (ALLOW, '', '') if marked(%input, 'packet');
    my $file = (%input<tool_input><file_path> // %input<tool_input><path> // '').Str;
    return (ALLOW, '', '') if $file && $file.IO.basename ~~ /:i ^ [readme|changelog|changes|license|licence|notes?] [\.\w+]? $ | \.md $ | \.txt $ /;
    my $packet = try packet-text(agent-packet($iz4));
    without $packet {
        return (ALLOW, '', "iz4: {$!.message.lines.head}\n");
    }
    mark(%input, 'packet');
    (REFUSE, '',
     "iz4: this repository keeps an IZ4, and the packet had not been delivered to this session. "
     ~ "Here it is; read it, then make the change.\n\n$packet");
}

#| Before a turn ends: if tracked files changed and the reply carries no
#| per-invariant report, refuse once with the format.  The harness's
#| 'stop_hook_active' guards against looping, and so does a mark.
sub on-stop(IO::Path $iz4, %input --> List) is export {
    return (ALLOW, '', '') if %input<stop_hook_active>;
    return (ALLOW, '', '') if marked(%input, 'reported');
    return (ALLOW, '', '') unless changed-since-start($iz4, %input);
    my $last = last-assistant-text(%input<transcript_path>);
    if $last ~~ /:i 'invariant' .* 'assessment' .* [ 'evidence' | 'remaining gap' ] / {
        mark(%input, 'reported');
        return (ALLOW, '', '');
    }
    mark(%input, 'reported');
    (REFUSE, '',
     "iz4: files changed in a repository that keeps an IZ4, and the reply gives no per-invariant report. "
     ~ "Before finishing, report each invariant the change could affect:\n"
     ~ "    Invariant:     its name and wording\n"
     ~ "    Assessment:    mechanically verified | supported by evidence | apparently consistent | uncertain | conflicting\n"
     ~ "    Evidence:      what was actually run or reviewed, and what was only suggested\n"
     ~ "    Remaining gap: what has not been established\n"
     ~ "Say 'uncertain' rather than imply conformance. 'iz4 invariants' lists them.\n");
}

#| Whether the repository's tracked files differ from the last commit, or
#| commits were made since the session's packet mark.
sub changed-since-start(IO::Path $iz4, %input --> Bool) {
    my ($rc, $out, $) = git($iz4, 'status', '--porcelain', '--untracked-files=no');
    return True if $rc == 0 && $out.trim;
    my $mark = mark-dir().add(session-id(%input) ~ '.packet');
    return False unless $mark.e;
    my ($rc2, $log, $) = git($iz4, 'log', '--format=%h', "--since={$mark.slurp.trim}");
    $rc2 == 0 && ?$log.trim;
}

#| The last assistant message in a Claude Code transcript (JSON lines),
#| or an empty string when there is none to read.
sub last-assistant-text(Str $path --> Str) is export {
    return '' unless $path && $path.IO.f;
    my $text = '';
    for $path.IO.lines -> $line {
        my $rec = try Rakudo::Internals::JSON.from-json($line);
        next unless $rec ~~ Associative && ($rec<type> // '') eq 'assistant';
        my $content = $rec<message><content> // $rec<content>;
        my @parts = $content ~~ Positional
            ?? $content.grep({ $_ ~~ Associative && ($_<type> // '') eq 'text' }).map(*<text>)
            !! ($content // '',);
        $text = @parts.join("\n") if @parts.join.trim;
    }
    $text;
}

# ------------------------------------------- wiring an earlier iz4 wrote

#| Until 0.15.0 iz4 wrote its own hook commands into Claude Code's
#| project settings.  It writes none now: an environment driver does.
#| The entries it left are still there and still fire, so status has to
#| be able to say so.  This only reads, and looks only for iz4's own
#| commands: it is how an old installation is recognised and left alone,
#| not a way to make a new one.
constant LEGACY-SETTINGS is export = '.claude/settings.json';
constant LEGACY-EVENTS = ('session-start', 'pre-edit', 'stop');

#| The iz4 hook events an earlier iz4 left wired here, in the order they
#| fire.  Empty when there are none or the file cannot be read.
sub legacy-hooks(IO::Path :$root! --> List) is export {
    my $target = $root.add(LEGACY-SETTINGS);
    return () unless $target.f;
    my $parsed = try Rakudo::Internals::JSON.from-json($target.slurp);
    return () unless $parsed ~~ Associative && $parsed<hooks> ~~ Associative;
    my %seen;
    for $parsed<hooks>.values -> $entries {
        next unless $entries ~~ Positional;
        for @$entries -> $entry {
            next unless $entry ~~ Associative && $entry<hooks> ~~ Positional;
            for @($entry<hooks>) -> $h {
                next unless $h ~~ Associative && ($h<command> // '') ~~ Str;
                my $cmd = $h<command>.trim;
                for LEGACY-EVENTS -> $e {
                    %seen{$e} = True if $cmd eq "iz4 hook $e" || $cmd.ends-with("/iz4 hook $e") || $cmd.ends-with(" iz4 hook $e");
                }
            }
        }
    }
    LEGACY-EVENTS.grep({ %seen{$_} }).List;
}

#| What that wiring does, said for a person.  It counts as AWARE and no
#| more: it delivers the packet and looks for a report, and puts neither
#| an action nor the change to a check.
sub legacy-hooks-lines(@events, Str :$migration! --> List) is export {
    my @does = 'the packet is delivered at session start';
    @does.push('one edit made before it is refused') if @events.grep('pre-edit');
    @does.push('one turn end without a report is refused') if @events.grep('stop');
    ("Claude Code hooks: active ({@events.join(', ')})",
     "  Managed by: legacy IZ4 wiring ({LEGACY-SETTINGS}, written by an earlier iz4; left exactly as it is)",
     "  Enforcement: AWARE ({@does.join('; ')}; no action and no change is checked)",
     "  Migration: $migration").List;
}
