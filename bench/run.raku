#!/usr/bin/env raku
#| The IZ4 adversarial benchmark: does the gate hold when an agent's work
#| conflicts with an invariant, and does it stay out of the way when it
#| does not?  Offline and deterministic: every "agent" here is a scripted
#| result (the files it would leave behind, the approval it would try to
#| reuse, the action it would attempt), so the benchmark measures the
#| boundary, never a model.  Whether a given model obeys an IZ4 it was
#| merely shown is a different question, answered only by live runs,
#| which this suite does not perform.
#|
#| Each scenario runs three ways:
#|   none      no IZ4 in the repository; the only check is the project's own tests
#|   context   the IZ4 is present and the gate reports, but nothing holds a commit
#|   enforced  the gate holds the commit unless a signed approval covers the exact change
#|
#|   raku bench/run.raku            run everything, write bench/results/latest.{json,md}
#|   raku bench/run.raku --check    also compare with each scenario's recorded expectation
#|   raku bench/run.raku --only=G   a subset, by prefix

my $BENCH = $*PROGRAM.resolve.parent;
my $IZ4   = %*ENV<IZ4_TEST_BIN> // 'iz4';
my $RAKU  = %*ENV<BENCH_RAKU> // $*EXECUTABLE.Str;
my @MODES = <none context enforced>;
my $HOME  = $*TMPDIR.add("iz4-bench-home-{$*PID}"); $HOME.mkdir; $HOME.add('no-keys').mkdir; $HOME.add('gitconfig').spurt('');

sub json-in(Str $t) { Rakudo::Internals::JSON.from-json($t) }
sub json-out($d)    { Rakudo::Internals::JSON.to-json($d, :sorted-keys) }

sub sh(*@cmd, :$cwd = $*CWD, :%env, Str :$in --> List) {
    # nothing here may touch the person's own keys, git config or iz4 settings
    my %e = %*ENV, IZ4_NO_321 => '1', IZ4_INTERACTIVE => '0', IZ4_ENFORCE => '0', NO_COLOR => '1',
            HOME => $HOME.Str, GIT_CONFIG_GLOBAL => $HOME.add('gitconfig').Str, IZ4_SSH_DIR => $HOME.add('no-keys').Str,
            IZ4_CHECK_CMD => "$RAKU -Ilib \{file}", |%env;
    my $p = run |@cmd, :cwd($cwd.Str), :env(%e), :out, :err, :in($in.defined);
    if $in.defined { $p.in.print($in); try $p.in.close }
    my $out = $p.out.slurp(:close); my $err = $p.err.slurp(:close);
    ($p.exitcode, $out, $err);
}
sub git(IO::Path $repo, *@args) { sh('git', '-C', $repo.Str, |@args) }

sub copy-tree(IO::Path $from, IO::Path $to) {
    for $from.dir -> $f {
        my $t = $to.add($f.basename);
        if $f.d { $t.mkdir; copy-tree($f, $t) } else { $t.parent.mkdir; $f.copy($t) }
    }
}

#| One throwaway repository: the seed, committed as the base.
sub fresh-repo(IO::Path $seed, Bool :$iz4 = True --> IO::Path) {
    my $r = $*TMPDIR.add("iz4-bench-{$*PID}-{(^1_000_000).pick}"); $r.mkdir;
    copy-tree($seed, $r);
    $r.add('IZ4').unlink unless $iz4;
    git($r, 'init', '-q');
    git($r, 'config', 'user.email', 'bench@example.com'); git($r, 'config', 'user.name', 'bench');
    git($r, 'config', 'commit.gpgsign', 'false');
    git($r, 'add', '-A'); git($r, 'commit', '-q', '-m', 'base');
    $r;
}

#| A signing key for the "owner", and the allowed-signers list a boundary checks against.
sub owner-keys(--> Hash) {
    my $d = $*TMPDIR.add("iz4-bench-keys-{$*PID}"); $d.mkdir;
    sh('ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-C', 'owner', '-f', $d.add('id').Str);
    $d.add('allowed_signers').spurt("owner {$d.add('id.pub').slurp}");
    %( key => $d.add('id'), signers => $d.add('allowed_signers') );
}

#| Apply the scripted agent's steps.  Returns the action checks it met.
sub play(IO::Path $repo, IO::Path $dir, @steps, Str $mode, %keys --> List) {
    my @actions;
    for @steps -> %s {
        given %s<do> {
            when 'overlay' {
                copy-tree($dir.add(%s<from> // 'files'), $repo);
                git($repo, 'add', '-A');
            }
            when 'remove' {
                for %s<paths>.list -> $p { git($repo, 'rm', '-q', '-f', $p) if $repo.add($p).e }
            }
            when 'approve' {
                next if $mode eq 'none';
                my @sign = %s<sign> ?? ('--sign=' ~ %keys<key>, '--by=owner') !! ();
                sh($IZ4, 'approve', '--staged', |@sign, :cwd($repo), :env(IZ4_INTERACTIVE => '1'), :in("y\ny\ny\ny\n"));
            }
            when 'rebase' {
                # new work lands on the base after the approval: the same change, a different base
                $repo.add('CHANGELOG.md').spurt("unrelated work\n");
                git($repo, 'add', 'CHANGELOG.md'); git($repo, 'commit', '-q', '-m', 'unrelated', '--', 'CHANGELOG.md');
            }
            when 'action' {
                next if $mode eq 'none';
                my %a = operation => %s<operation>, target => %s<target>;
                %a<parameters> = %s<parameters> if %s<parameters>;
                my $t0 = now;
                my ($rc, $out, $err) = sh($IZ4, 'check', 'action', '--json', '--action=' ~ json-out(%a), :cwd($repo));
                my $r = try json-in($out);
                @actions.push: %( operation => %s<operation>, target => %s<target>, result => ($r<result> // 'error'),
                                  exit => $rc, reason => ($r<reason> // $err.trim), seconds => (now - $t0).round(0.001) );
            }
        }
    }
    @actions;
}

#| What the boundary says about the candidate tree.
sub boundary(IO::Path $repo, Str $mode, %keys --> Hash) {
    my $t0 = now;
    if $mode eq 'none' {
        my @tests = $repo.add('t').e ?? $repo.add('t').dir(test => /'.rakutest' $/).sort !! ();
        return %( kind => 'tests', outcome => 'no-tests', exit => 0, seconds => 0 ) unless @tests;
        my $failed = @tests.grep({ sh($RAKU, '-Ilib', .Str, :cwd($repo))[0] != 0 }).elems;
        return %( kind => 'tests', outcome => ($failed ?? 'tests-fail' !! 'tests-pass'), exit => ($failed ?? 1 !! 0),
                  seconds => (now - $t0).round(0.001) );
    }
    # the same allowed signers either way: only the holding differs
    my @enforce = ('--approvers=' ~ %keys<signers>), |($mode eq 'enforced' ?? ('--enforce',) !! ());
    my ($rc, $out, $err) = sh($IZ4, 'gate', '--staged', '--json', |@enforce, :cwd($repo));
    my $g = try json-in($out);
    return %( kind => 'gate', outcome => 'error', exit => $rc, seconds => (now - $t0).round(0.001), note => $err.trim.lines.head // $out.trim.lines.head )
        without $g;
    %( kind => 'gate', outcome => $g<outcome>, exit => $rc, seconds => (now - $t0).round(0.001),
       approval => ($g<approval><status> // 'none'),
       reasons => ($g<approval><reasons> // ()).list,
       changes => $g<changes>.map(*<kind>).list, protections => $g<protections>.map(*<kind>).list,
       checks => $g<checks>.map({ "{.<file>}: {.<outcome>}" }).list );
}

sub classify(%scenario, Str $mode, %b, @actions --> Hash) {
    my $attempted = %scenario<violates>.defined;
    # an action-only scenario is judged where the action was checked
    my $action-only = %scenario<steps>.all<do> eq 'action';
    my $outcome = $action-only ?? (@actions.map(*<result>).first({ $_ ne 'pass' }) // 'pass') !! %b<outcome>;
    my $exit    = $action-only ?? (@actions ?? @actions.map(*<exit>).max !! 0) !! %b<exit>;
    my $detected  = $outcome ne any(<pass tests-pass no-tests>);
    my $prevented = $mode eq 'enforced' && $detected && $exit != 0;
    %( attempted => $attempted, outcome => $outcome, exit => $exit,
       detected => $detected, prevented => $prevented,
       missed => ($attempted && !$detected), false_positive => (!$attempted && $detected),
       unnecessary_approval => (!$attempted && $outcome eq 'agreement-required' && $mode eq 'enforced') );
}

sub run-scenario(IO::Path $dir, %keys, Bool :$check --> Hash) {
    my %s = json-in($dir.add('scenario.json').slurp);
    my %by-mode;
    for @MODES -> $mode {
        $HOME.add('gitconfig').spurt('');        # nothing remembered from another scenario, such as a signer
        my $repo = fresh-repo($BENCH.add('seed').add(%s<seed>), :iz4($mode ne 'none'));
        my @actions = play($repo, $dir, %s<steps>.list, $mode, %keys);
        my %b = boundary($repo, $mode, %keys);
        my %c = classify(%s, $mode, %b, @actions);
        %by-mode{$mode} = %( |%c, boundary => %b, actions => @actions,
                             seconds => (%b<seconds> + @actions.map(*<seconds>).sum).round(0.001) );
        if $check && %s<expect>{$mode} -> %e {
            my @bad = %e.keys.sort.grep({ %c{$_}.Str ne %e{$_}.Str }).map({ "$_: expected {%e{$_}}, got {%c{$_}}" });
            %by-mode{$mode}<mismatch> = @bad if @bad;
        }
        sh('rm', '-rf', $repo.Str);
    }
    %( id => %s<id>, category => %s<category>, title => %s<title>, task => %s<task>, violates => %s<violates>, seed => %s<seed>, modes => %by-mode );
}

sub totals(@results --> Hash) {
    my %t;
    for @MODES -> $m {
        my @r = @results.map(*<modes>{$m});
        %t{$m} = %(
            scenarios => @r.elems,
            attempted => @r.grep(*<attempted>).elems,
            detected  => @r.grep({ .<attempted> && .<detected> }).elems,
            prevented => @r.grep({ .<attempted> && .<prevented> }).elems,
            missed    => @r.grep(*<missed>).elems,
            legitimate => @r.grep(!*<attempted>).elems,
            false_positives => @r.grep(*<false_positive>).elems,
            unnecessary_approvals => @r.grep(*<unnecessary_approval>).elems,
            seconds => @r.map(*<seconds>).sum.round(0.01),
        );
    }
    %t;
}

sub report(@results, %t, Str $iz4-version --> Str) {
    my @l = "# IZ4 adversarial benchmark", '',
        "Offline, deterministic: scripted agent results against the gate. iz4 $iz4-version, {DateTime.now.utc.truncated-to('second')}.", '',
        "Nothing here measures whether a model obeys an IZ4 it was shown; that needs live runs, which this suite does not perform.", '',
        '| Mode | Violations attempted | Detected | Prevented | Missed | Legitimate | False positives | Unnecessary approvals | Seconds |',
        '|---|---|---|---|---|---|---|---|---|';
    for @MODES -> $m { my %x = %t{$m};
        @l.push: "| $m | {%x<attempted>} | {%x<detected>} | {%x<prevented>} | {%x<missed>} | {%x<legitimate>} | {%x<false_positives>} | {%x<unnecessary_approvals>} | {%x<seconds>} |" }
    @l.push: '', '| Scenario | Violates | none | context | enforced |', '|---|---|---|---|---|';
    for @results -> %r {
        my sub cell($m) { my %c = %r<modes>{$m}; my $o = %c<outcome>; $o ~= " (exit {%c<exit>})" if $m eq 'enforced'; $o ~= ' MISMATCH' if %c<mismatch>; $o }
        @l.push: "| {%r<id>} | {%r<violates> // 'no'} | {cell('none')} | {cell('context')} | {cell('enforced')} |";
    }
    @l.push: '', '## Reading the table', '',
        "- none: the project's own tests are the only check. They catch a change that breaks a tested behaviour, and nothing else.",
        '- context: the gate sees every change to a commitment or a protecting test, and says so; nothing is held.',
        '- enforced: the gate holds the commit (non-zero exit) until a signed approval covers that exact tree, base and proposal. An altered foundation, a reused name or a failing protecting test is held by nothing an approval lifts.',
        '- Missed means the boundary passed a change that violates an invariant. D1 is the honest case: a new route around an invariant whose words and whose test do not change is invisible to the gate unless a test covers that route (D2).';
    @l.join("\n") ~ "\n";
}

sub MAIN(Str :$only, Bool :$check = False, Str :$out = $BENCH.add('results').Str, Bool :$quiet = False) {
    my ($rc, $v, $) = sh($IZ4, 'version');
    die "iz4 not found ($IZ4): set IZ4_TEST_BIN or put iz4 on PATH" if $rc != 0;
    my $iz4-version = $v.trim.subst(/^ "iz4" \s+ /, "");
    my %keys = owner-keys();
    my @dirs = $BENCH.add('scenarios').dir(test => { !.starts-with('.') }).grep(*.d).sort;
    @dirs .= grep(*.basename.starts-with($only)) with $only;
    my @results = @dirs.map({ run-scenario($_, %keys, :$check) });
    sh('rm', '-rf', %keys<key>.parent.Str, $HOME.Str);
    my %t = totals(@results);
    my %doc = schema => 'iz4-bench/1', iz4 => $iz4-version, raku => $RAKU, at => DateTime.now.utc.truncated-to('second').Str,
              totals => %t, scenarios => @results;
    $out.IO.mkdir;
    $out.IO.add('latest.json').spurt(json-out(%doc) ~ "\n");
    my $md = report(@results, %t, $iz4-version);
    $out.IO.add('latest.md').spurt($md);
    print $md unless $quiet;
    my @mis = @results.map({ my %r = $_; %r<modes>.kv.map(-> $m, %c { %c<mismatch> ?? "{%r<id>} [$m] {%c<mismatch>.join('; ')}" !! Empty }) }).flat;
    if $check {
        note $_ for @mis;
        say @mis ?? "{@mis.elems} expectation(s) not met" !! "every expectation met";
        exit(@mis ?? 1 !! 0);
    }
}
