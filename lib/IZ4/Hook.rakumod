unit module IZ4::Hook;

#| Harness hooks: the parts of the protocol a harness can insist on.
#|
#| A model cannot be made to obey prose, but a harness that runs a
#| command before a session starts, before a tool call and before a turn
#| ends can refuse to let the mechanical steps be skipped: the packet is
#| loaded, nothing is edited before it is, and a turn that changed files
#| does not end without the per-invariant report.  None of that proves
#| an invariant was honoured; it proves the agent had the packet and
#| wrote the report.
#|
#| The core is harness-neutral: 'iz4 hook <event>' reads the harness's
#| JSON on standard input, prints for the model on standard output, and
#| refuses with exit code 2 and a reason on standard error.  Claude Code
#| speaks exactly this contract; an adapter for another harness only has
#| to call the same command.

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
     ~ "    Invariant:     its number and wording\n"
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

# ------------------------------------------------------- Claude Code adapter

constant SETTINGS-PATH is export = '.claude/settings.json';

#| The hook entries for Claude Code's settings.json.  The two blocking
#| hooks are :strict only; the session-start hook is always installed.
sub claude-hooks(Bool :$strict = False --> Hash) is export {
    # $%( ) keeps each hash whole: a bare %( ) inside [ ] flattens to pairs
    my sub entry(Str $command, Str :$matcher) {
        my %e = hooks => [ $%( type => 'command', command => $command ) ];
        %e<matcher> = $matcher with $matcher;
        $%e;
    }
    my %h = SessionStart => [ entry('iz4 hook session-start', :matcher<startup|resume|compact>) ];
    if $strict {
        %h<PreToolUse> = [ entry('iz4 hook pre-edit', :matcher<Edit|Write|MultiEdit|NotebookEdit>) ];
        %h<Stop>       = [ entry('iz4 hook stop') ];
    }
    %h;
}

#| Install or refresh the hooks in a repository's .claude/settings.json,
#| keeping every other setting and every hook that is not ours.  Returns
#| 'installed', 'updated' or 'unchanged'; refuses to touch a file it
#| cannot parse.
sub install-claude-hooks(IO::Path :$root!, Bool :$strict = False --> Str) is export {
    my $target = $root.add(SETTINGS-PATH);
    my %settings;
    if $target.e {
        my $parsed = try Rakudo::Internals::JSON.from-json($target.slurp);
        X::IZ4.new(message => "{SETTINGS-PATH} is not valid JSON; fix it by hand, nothing was changed").throw
            unless $parsed ~~ Associative;
        %settings = %$parsed;
    }
    my $before = json-encode(%settings);
    my %hooks = %(%settings<hooks> // %());
    # drop our entries everywhere, then add the current set
    for %hooks.keys -> $event {
        %hooks{$event} = [ %hooks{$event}.grep({ !ours($_) }) ];
        %hooks{$event}:delete unless %hooks{$event}.elems;
    }
    for claude-hooks(:$strict).kv -> $event, @entries {
        %hooks{$event} = [ |(%hooks{$event} // ()), |@entries ];
    }
    %settings<hooks> = %hooks;
    my $after = json-encode(%settings);
    return 'unchanged' if $after eq $before;
    $target.parent.mkdir;
    $target.spurt(pretty-json(%settings) ~ "\n");
    $before eq '{}' || !%settings<hooks>.keys.grep({ $before.contains("\"$_\"") }) ?? 'installed' !! 'updated';
}

sub ours($entry --> Bool) {
    $entry ~~ Associative && ($entry<hooks> // ()).grep({ ($_<command> // '').starts-with('iz4 hook') }).so;
}

#| Which of our hooks a settings file carries: 'none', 'start' or 'strict'.
sub claude-hooks-status(IO::Path :$root! --> Str) is export {
    my $target = $root.add(SETTINGS-PATH);
    return 'none' unless $target.e;
    my $parsed = try Rakudo::Internals::JSON.from-json($target.slurp);
    return 'none' unless $parsed ~~ Associative && $parsed<hooks> ~~ Associative;
    my %hooks = %($parsed<hooks>);
    my $start  = (%hooks<SessionStart> // ()).grep(&ours).so;
    my $strict = (%hooks<PreToolUse> // ()).grep(&ours).so && (%hooks<Stop> // ()).grep(&ours).so;
    $strict ?? 'strict' !! $start ?? 'start' !! 'none';
}

#| Readable JSON, two-space indented, keys sorted.
sub pretty-json($v, Int :$depth = 0 --> Str) is export {
    my $pad = '  ' x $depth;
    my $in  = '  ' x ($depth + 1);
    given $v {
        when Associative {
            return '{}' unless .elems;
            '{' ~ "\n" ~ .pairs.sort(*.key).map({ $in ~ json-encode(.key.Str) ~ ': ' ~ pretty-json(.value, :depth($depth + 1)) }).join(",\n") ~ "\n$pad}"
        }
        when Positional {
            return '[]' unless .elems;
            '[' ~ "\n" ~ .map({ $in ~ pretty-json($_, :depth($depth + 1)) }).join(",\n") ~ "\n$pad]"
        }
        default { json-encode($v) }
    }
}
