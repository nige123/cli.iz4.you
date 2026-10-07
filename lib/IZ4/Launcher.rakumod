unit module IZ4::Launcher;

#| 321.do, an agent launcher, under iz4.
#|
#| 321 is the free, harness-agnostic agent runtime from 321.do: it takes a
#| work package, picks a harness it can hold to the package's limits, runs
#| the agent, and comes back with a receipt.  When it is on the machine,
#| iz4 uses it for everything agentic - suggest, review, test drafting -
#| and for wiring hooks into whatever harnesses 321 knows, and quotes what
#| 321 says each of them enforces.  When it is not, iz4 falls back to its
#| own agent command and its own Claude Code wiring, so the core CLI
#| works alone (Invariant 5).  Nothing here parses an IZ4 through 321:
#| 321 runs iz4 for that.


#| The first 321 this runtime needs: hooks, doctor --json, the prompt
#| package and a request from stdin arrived in 0.3.1.
constant LAUNCHER-MIN-VERSION is export = '0.3.1';

#| The 321 executable: IZ4_321 names it, else `321` on PATH; Str when
#| absent, or when what is there is not a 321 new enough to use (the name
#| is short and other tools have carried it).
sub launcher-binary(--> Str) is export {
    # IZ4_NO_321=1 makes iz4 behave as if 321 were not installed, for the
    # installer's opt-out and for tests that pin iz4's own fallback.
    return Str if (%*ENV<IZ4_NO_321> // '') ne '' && (%*ENV<IZ4_NO_321> // '') ne '0';
    my @candidates;
    with %*ENV<IZ4_321> { @candidates.push($_) if $_.IO.f }
    my $sep = $*DISTRO.is-win ?? ';' !! ':';
    for (%*ENV<PATH> // '').split($sep).grep(* ne '') -> $d {
        for '321', |($*DISTRO.is-win ?? ('321.exe',) !! ()) -> $n {
            my $f = $d.IO.add($n);
            @candidates.push($f.Str) if $f.f && ($*DISTRO.is-win || $f.x);
        }
    }
    for @candidates -> $c {
        return $c if launcher-usable($c);
    }
    Str;
}

#| Whether an executable is a 321 of at least LAUNCHER-MIN-VERSION.
sub launcher-usable(Str $bin --> Bool) is export {
    my $v = launcher-version($bin);
    return False unless $v ~~ /^ \d+ '.' \d+ ('.' \d+)? /;
    version-at-least($v, LAUNCHER-MIN-VERSION);
}

sub version-at-least(Str $have, Str $want --> Bool) {
    my @h = $have.split('.').map({ (.match(/^\d+/) // 0).Int });
    my @w = $want.split('.').map(*.Int);
    for ^3 -> $i {
        my ($a, $b) = @h[$i] // 0, @w[$i] // 0;
        return True if $a > $b;
        return False if $a < $b;
    }
    True;
}

#| Run 321 with arguments; returns (exit code, stdout, stderr).
sub launcher-run(Str $bin, *@args, Str :$in = '', IO::Path :$cwd --> List) is export {
    my $p = run $bin, |@args, :in, :out, :err, |($cwd ?? (:cwd($cwd.Str)) !! ());
    $p.in.print($in);
    my $ = try $p.in.close;        # sunk, a non-zero exit would throw here; the code is read below
    my $out = $p.out.slurp(:close);
    my $err = $p.err.slurp(:close);
    ($p.exitcode, $out, $err);
}

#| The version 321 reports, or '' when it cannot be run or is not a 321.
sub launcher-version(Str $bin --> Str) is export {
    my ($rc, $out, $) = try launcher-run($bin, 'version');
    return '' if $! || $rc != 0;
    my $line = $out.trim.lines.head // '';
    return '' unless $line ~~ /^ '321' \s+ (\d+ '.' \d+ ['.' \d+]?) /;
    ~$0;
}

sub parse-json(Str $text) { my $v = try Rakudo::Internals::JSON.from-json($text); $! ?? Any !! $v }

#| The prompt-only package 321 ships, written out and its path printed.
sub launcher-prompt-package(Str $bin --> Str) is export {
    my ($rc, $out, $err) = launcher-run($bin, 'packages', 'builtin', 'prompt');
    die "321 could not write its prompt package: {$err.trim || $out.trim}" unless $rc == 0 && $out.trim;
    $out.trim;
}

#| Ask an agent through 321: a prompt-only run with nothing granted but
#| reading, answered in text.  Dies with what 321 said when the run did
#| not complete.
sub ask-via-launcher(Str $bin, Str $prompt, IO::Path :$root = $*CWD --> Str) is export {
    my $pkg = launcher-prompt-package($bin);
    my ($rc, $out, $err) = launcher-run($bin, '--package-dir', $pkg, '--workspace', $root.Str, '--non-interactive', '--json', 'prompt', '-', :in($prompt), :cwd($root));
    my $receipt = $out.lines.reverse.map({ parse-json($_) }).first({ $_ ~~ Associative && ($_<schema> // '') eq 'run-receipt.v1' });
    without $receipt {
        my $perr = $out.lines.map({ parse-json($_) }).first({ $_ ~~ Associative && ($_<schema> // '') eq 'protocol-error.v1' });
        die "321 gave no receipt" ~ ($perr.defined ?? ": {$perr<code>}: {$perr<message>}" !! ($err.trim ?? ": {$err.trim.lines.head}" !! ''));
    }
    given $receipt<status> // '' {
        when 'completed' | 'no_change' { return ($receipt<summary> // '').Str }
        when 'blocked' { die "the agent stopped to ask: {$receipt<blockedOn> // '(no question)'}" }
        when 'denied'  { die "321 refused the run: {$receipt<denied><reason> // 'no reason'}" ~ (($receipt<denied><details> // []).elems ?? " ({$receipt<denied><details>.join('; ')})" !! '') }
        default        { die "the agent run {$receipt<status>}: " ~ (($receipt<evidence><errors> // []).join('; ') || $receipt<summary> // '') }
    }
}

#| The first 321 that can drive iz4 in an agent environment: it detects
#| harnesses, wires and verifies iz4 in them (`321 iz4 install | status |
#| remove`) and translates their events for iz4's machine interface.
constant DRIVER-MIN-VERSION is export = '0.4.0';

#| The environment driver: a 321 new enough to wire a harness, or Str.
#| iz4 knows no harness itself; what knows one is a driver.
sub driver-binary(--> Str) is export {
    my $bin = launcher-binary();
    return Str without $bin;
    version-at-least(launcher-version($bin), DRIVER-MIN-VERSION) ?? $bin !! Str;
}

#| Ask the driver to install, report on or remove iz4's wiring in every
#| harness it knows; its answer is an enforcement-report.v1 document.
#| :advisory wires only the context, so nothing is refused.
sub driver(Str $bin, Str $action, IO::Path :$root!, Bool :$advisory = False --> Hash) is export {
    my ($rc, $out, $err) = launcher-run($bin, 'iz4', $action, '--workspace', $root.Str, |($advisory ?? ('--advisory',) !! ()), '--json');
    my $doc = parse-json($out);
    die "321 iz4 $action failed: {$err.trim || $out.trim}" unless $doc ~~ Associative;
    %$doc;
}

#| What 321 knows about the installed harnesses (doctor.v1).
sub launcher-doctor(Str $bin --> Hash) is export {
    my ($rc, $out, $err) = launcher-run($bin, 'doctor', '--json');
    my $doc = parse-json($out);
    die "321 doctor failed: {$err.trim || $out.trim}" unless $doc ~~ Associative;
    %$doc;
}

#| What the driver reports, a harness at a time: what it did, the
#| enforcement that is really in place, and its warnings.
sub driver-lines(%doc --> List) is export {
    my @out;
    for @(%doc<harnesses> // []) -> %h {
        @out.push(%h<harness> ~ (%h<detected> ?? '' !! ' (not detected here)')
            ~ ((%h<action> // '') ne '' ?? ": {%h<action>};" !! ':')
            ~ " enforcement {%h<headline> // 'NONE'}"
            ~ (@(%h<levels> // []) ?? " ({@(%h<levels>).join(', ')})" !! ''));
        @out.push("  ! {%h<error>}") if (%h<error> // '') ne '';
        @out.push("  $_") for @(%h<warnings> // []);
    }
    @out;
}

#| The strongest protection the driver reports across harnesses: guarded,
#| checked, aware or none.
sub driver-level(%doc --> Str) is export {
    my @h = @(%doc<harnesses> // []).map({ (.<headline> // 'NONE').lc });
    for <guarded checked aware> -> $l { return $l if @h.grep($l) }
    'none';
}

#| How an agent is reached, in words for a message: the person's own
#| command when IZ4_AGENT_CMD is set, else 321 when it is installed, else
#| the default command.
sub agent-label(--> Str) is export {
    return %*ENV<IZ4_AGENT_CMD> if %*ENV<IZ4_AGENT_CMD>;
    with launcher-binary() { return "321, an agent launcher ({$_})" }
    'claude -p';
}

#| Ask an agent and get its reply as text.  With IZ4_AGENT_CMD (or an
#| explicit :cmd) the prompt goes to that command on standard input and
#| its standard output is the reply; otherwise, when 321 is installed, the
#| prompt is a read-only run through it, on whatever harness it picks;
#| otherwise `claude -p`.  Dies with what went wrong.
sub ask-agent(Str $prompt, IO::Path :$root = $*CWD, Str :$cmd --> Str) is export {
    my $command = $cmd // %*ENV<IZ4_AGENT_CMD>;
    if !$command.defined {
        with launcher-binary() { return ask-via-launcher($_, $prompt, :$root) }
        $command = 'claude -p';
    }
    my $proc = run '/bin/sh', '-c', $command, :in, :out, :cwd($root.Str);
    $proc.in.print($prompt);
    my $ = $proc.in.close;
    my $reply = $proc.out.slurp(:close);
    die "agent command failed ($command)" if $proc.exitcode != 0;
    $reply;
}

# ------------------------------------------------------------------ install

constant LAUNCHER-RELEASES is export = 'https://github.com/nige123/cli.321.do/releases';
constant LAUNCHER-API      is export = 'https://api.github.com/repos/nige123/cli.321.do/releases/latest';

#| The 321 release file built for this operating system and processor.
sub launcher-asset(--> Str) is export {
    my $arch = $*KERNEL.hardware.lc;
    $arch = 'aarch64' if $arch eq 'arm64';
    given $*KERNEL.name.lc {
        when 'linux'  { $arch eq 'x86_64' | 'aarch64' ?? "321-linux-$arch" !! Str }
        when 'darwin' { '321-macos-universal' }
        when /win/    { $arch eq 'x86_64' | 'amd64' ?? '321-windows-x64.exe' !! Str }
        default       { Str }
    }
}

sub launcher-latest-tag(--> Str) is export {
    if %*ENV<IZ4_321_RELEASE_URL> {
        my $p = run 'curl', '-fsSL', "{%*ENV<IZ4_321_RELEASE_URL>}/latest.txt", :out, :err;
        my $tag = $p.out.slurp(:close).trim; $p.err.slurp(:close);
        return $p.exitcode == 0 && $tag ?? $tag !! Str;
    }
    my $p = run 'curl', '-fsSL', '-H', 'Accept: application/vnd.github+json', LAUNCHER-API, :out, :err;
    my $body = $p.out.slurp(:close); $p.err.slurp(:close);
    return Str if $p.exitcode != 0;
    # the capture is read from the Match itself: inside a `with` block $0 is not the outer $/
    my $m = $body.match(/ '"tag_name"' \s* ':' \s* '"' (<-["]>+) '"' /);
    return $m[0].Str if $m && $m[0].Str ~~ /^ 'v' \d/;
    Str;
}

sub launcher-release-base(Str $tag --> Str) { %*ENV<IZ4_321_RELEASE_URL> // "{LAUNCHER-RELEASES}/download/$tag" }

#| sha256 of a file through whichever digest tool the system has.
sub digest-file(IO::Path $f --> Str) {
    for ('sha256sum',), ('shasum', '-a', '256'), ('openssl', 'dgst', '-sha256', '-r') -> @tool {
        my $hex = try {
            my $p = run |@tool.map(*.Str), $f.Str, :out, :err;
            my $o = $p.out.slurp(:close); $p.err.slurp(:close);
            $p.exitcode == 0 ?? $o.words.head !! Nil;
        };
        return $hex.lc if $hex.defined && $hex ~~ /^ <[0..9 A..F a..f]> ** 64 $/;
    }
    '';
}

#| The marker beside an iz4-installed 321, saying iz4 put it there and may
#| keep it current.  A 321 someone installed themselves is never touched.
sub launcher-marker(IO::Path $bin-dir --> IO::Path) is export { $bin-dir.add('.321-from-iz4') }

#| The directory holding a 321 that iz4 installed, if any: beside the
#| running program, or beside the iz4 on PATH (a source install's
#| launcher script, which runs the checkout's bin/iz4).
sub launcher-owner-dir(--> IO::Path) is export {
    my @dirs = $*PROGRAM.resolve.parent;
    my $sep = $*DISTRO.is-win ?? ';' !! ':';
    for (%*ENV<PATH> // '').split($sep).grep(* ne '') -> $d {
        my $f = $d.IO.add($*DISTRO.is-win ?? 'iz4.exe' !! 'iz4');
        @dirs.push($f.parent) if $f.f;
    }
    @dirs.first({ launcher-marker($_).e });
}

#| Install or update 321 into $bin-dir from the latest release.  Returns
#| a hash with state: 'installed', 'updated', 'current', 'skipped' (a 321
#| not ours is on PATH) or 'failed', and a note.
sub launcher-install(IO::Path :$bin-dir!, Bool :$check = False --> Hash) is export {
    my $target = $bin-dir.add($*DISTRO.is-win ?? '321.exe' !! '321');
    my $ours = launcher-marker($bin-dir).e;
    with launcher-binary() {
        return %( state => 'skipped', note => "321 is already installed at $_, not by iz4; left as is" )
            unless $ours && $_.IO.resolve.Str eq $target.resolve.Str;
    }
    my $asset = launcher-asset() // return %( state => 'failed', note => "no published 321 for {$*KERNEL.name} on {$*KERNEL.hardware}" );
    my $tag = launcher-latest-tag() // return %( state => 'failed', note => "could not find the latest 321 release at {LAUNCHER-RELEASES}" );
    my $have = $target.e ?? launcher-version($target.Str) !! '';
    return %( state => 'current', version => $have ) if $have ne '' && $tag eq "v$have";
    return %( state => $have ne '' ?? 'behind' !! 'missing', :$tag, version => $have ) if $check;
    my $base = launcher-release-base($tag);
    my $tmp = $*TMPDIR.add("iz4-321-{$*PID}-{(^1_000_000).pick}");
    $tmp.mkdir;
    LEAVE { try { .unlink for $tmp.dir; $tmp.rmdir } }
    for $asset, "$asset.sha256" -> $f {
        my $p = run 'curl', '-fsSL', '-o', $tmp.add($f).Str, "$base/$f", :out, :err;
        $p.out.slurp(:close); $p.err.slurp(:close);
        return %( state => 'failed', note => "could not fetch $f from $base" ) unless $p.exitcode == 0;
    }
    my $exp = $tmp.add("$asset.sha256").slurp.lc.match(/ <[0..9a..f]> ** 64 /);
    my $got = digest-file($tmp.add($asset));
    return %( state => 'failed', note => "checksum mismatch for $asset; nothing was installed" ) unless $exp.defined && ~$exp eq $got;
    $tmp.add($asset).chmod(0o755);
    my $v = launcher-version($tmp.add($asset).Str);
    return %( state => 'failed', note => "the published 321 does not run on this system" ) if $v eq '';
    $bin-dir.mkdir;
    $tmp.add($asset).move($target);
    launcher-marker($bin-dir).spurt("installed by iz4\n");
    %( state => ($have eq '' ?? 'installed' !! 'updated'), from => $have, version => $v, path => $target.Str );
}
