unit module IZ4::Gate;

#| The gate: does a change alter what this software has committed to?
#|
#| It compares two snapshots, a base tree and a candidate tree, never the
#| working directory: the staged index against HEAD, or two revisions for
#| CI.  From the two trees it reads the IZ4 and the tests that name
#| invariants, and reports what changed in plain categories:
#|
#|   commitments   IS FOR WHAT, IS FOR WHO, a project invariant added,
#|                 revised or removed, the foundation altered, the file
#|                 invalid or gone, a retired number reused
#|   protections   a test naming an invariant removed, no longer naming
#|                 it, or carrying a new skip marker
#|   checks        the tests naming invariants, run from the candidate
#|                 tree, each passed, failed, timed out or not runnable
#|   touches       which invariants the diff mentions by their own words
#|                 (a pointer for a person, never a finding)
#|
#| The outcome is one of five words with a stable exit code under
#| --enforce: pass, agreement-required, blocked, unassessed, error.  A
#| commitment or protection change needs a person's agreement; the gate
#| can recognise one only as a detached approval bound to this repository,
#| this base, this exact candidate tree and this exact proposal, so a
#| receipt can never sit inside the tree it approves.  A terminal yes is
#| recorded as such and counts for local checks; a protected boundary
#| accepts only an approval signed by a key in its own allowed-signers
#| file, which the candidate cannot edit.  The foundation, Invariants
#| 0-4, is never approvable: altering it is blocked.
#|
#| The checks run in an export of the candidate tree with the checkout's
#| ignored files (installed dependencies, local configuration) linked in:
#| tracked content from the snapshot, environment from the machine.  A
#| test that cannot start for want of a dependency is unassessed, never a
#| failure: the gate reports what it could not look at as exactly that.
#|
#| Trust boundary: everything here runs with the caller's authority.  A
#| local hook can be skipped and a local approval can be written by
#| whoever has the shell, so the gate's word is only as trustworthy as
#| the installation that runs it.  Protection comes from running it again
#| at an acceptance boundary (a required CI check on the protected branch,
#| a server-side hook) from an installation and an allowed-signers file
#| the candidate cannot change.  The gate says which tier it ran in and
#| never claims the other.

use IZ4;
use IZ4::Document;
use IZ4::Git;
use IZ4::Evidence;
use IZ4::Register;     # json-encode, json-field
use IZ4::Review;       # touched-invariants

constant GATE-SCHEMA     is export = 'iz4-gate/1';
constant PROPOSAL-SCHEMA is export = 'iz4-proposal/1';
constant APPROVAL-SCHEMA is export = 'iz4-approval/1';
constant APPROVAL-REFS   is export = 'refs/iz4/approvals/';
constant SIGN-NAMESPACE  is export = 'iz4-approval';

#| The outcomes, and the exit code each has under --enforce.  Advisory
#| mode prints the same outcome and exits 0 for all but error.
constant %EXIT-CODE is export = (pass => 0, error => 1, 'agreement-required' => 2, blocked => 3, unassessed => 4);
constant @REJECTS   is export = <agreement-required blocked unassessed error>;

constant @BLOCKING-KINDS  = <invalid foundation reused-number>;
constant @AGREEMENT-KINDS = <purpose people added revised removed removed-file>;
constant @PROTECTION-AGREEMENT-KINDS = <protection-removed protection-unlinked protection-weakened>;

sub gate-error(Str $message) { X::IZ4.new(:$message).throw }

# git() takes a file and runs in its parent, so any path under the root does
sub g(IO::Path $root, *@args) { git($root.add(ROOT-NAME), |@args) }

# ------------------------------------------------------------- snapshots

#| Which two trees to compare.  Staged: the index as a tree against
#| HEAD's tree (or none when HEAD is unborn).  Revisions: a candidate
#| revision's tree against an explicit base, its first parent, or none.
#| The repository identity is its root commit, the same in every clone.
sub snapshots(IO::Path $root, Bool :$staged = False, Str :$base, Str :$candidate --> Hash) is export {
    my %s;
    my ($rc, $out, $err);
    if $candidate.defined {
        ($rc, $out, $err) = g($root, 'rev-parse', '--verify', '--quiet', $candidate ~ '^{tree}');
        gate-error("candidate '$candidate' is not a revision in this repository") if $rc != 0;
        %s<candidate>     = $out.trim;
        %s<candidate_ref> = $candidate;
        if $base.defined && $base ne 'none' {
            ($rc, $out, $err) = g($root, 'rev-parse', '--verify', '--quiet', $base ~ '^{tree}');
            gate-error("base '$base' is not a revision in this repository") if $rc != 0;
            %s<base> = $out.trim;
            %s<base_ref> = $base;
        }
        elsif !$base.defined {
            ($rc, $out, $err) = g($root, 'rev-parse', '--verify', '--quiet', $candidate ~ '^1^{tree}');
            if $rc == 0 { %s<base> = $out.trim; %s<base_ref> = $candidate ~ '^1' }
            else        { %s<base_ref> = 'none' }     # a root commit
        }
        else { %s<base_ref> = 'none' }
        %s<selection>  = 'revisions';
        %s<repository> = root-commit($root, $candidate);
    }
    else {
        ($rc, $out, $err) = g($root, 'write-tree');
        gate-error("the index cannot be written as a tree ({$err.trim.lines.head // 'unmerged entries?'})") if $rc != 0;
        %s<candidate>     = $out.trim;
        %s<candidate_ref> = 'index';
        ($rc, $out, $err) = g($root, 'rev-parse', '--verify', '--quiet', 'HEAD^{tree}');
        if $rc == 0 { %s<base> = $out.trim; %s<base_ref> = 'HEAD' }
        else        { %s<base_ref> = 'none' }
        %s<selection>  = 'staged';
        %s<repository> = root-commit($root, 'HEAD');
    }
    %s;
}

sub root-commit(IO::Path $root, Str $rev --> Str) {
    my ($rc, $out, $) = g($root, 'rev-list', '--max-parents=0', $rev);
    $rc == 0 && $out.trim ne '' ?? $out.lines.sort.head.trim !! 'unborn';
}

#| One file from a tree, or Nil when the tree has none.
sub tree-file(IO::Path $root, Str $tree, Str $path --> Str) is export {
    my ($rc, $out, $) = g($root, 'show', "$tree:$path");
    $rc == 0 ?? $out !! Str;
}

#| A tree checked out into a fresh temporary directory, through a
#| temporary index, so nothing in the working directory is read.
sub export-tree(IO::Path $root, Str $tree, Bool :$tests-only = False --> IO::Path) is export {
    my $tag   = "iz4-gate-{$*PID}-{(^1_000_000).pick}";
    my $dir   = $*TMPDIR.add($tag);
    my $index = $*TMPDIR.add("$tag.index");
    $dir.mkdir;
    # GIT_INDEX_FILE points git at the temporary index for these two calls
    # only. Restored by hand: 'temp' on a key that did not exist leaves it
    # present and empty, and every later git command in a linked test then
    # fails to write its own index.
    my $had   = %*ENV<GIT_INDEX_FILE>:exists;
    my $was   = %*ENV<GIT_INDEX_FILE>;
    %*ENV<GIT_INDEX_FILE> = $index.Str;
    LEAVE { if $had { %*ENV<GIT_INDEX_FILE> = $was } else { %*ENV<GIT_INDEX_FILE>:delete }; try $index.unlink }
    my ($rc, $out, $err) = g($root, 'read-tree', $tree);
    gate-error("cannot read tree $tree: {$err.trim.lines.head // ''}") if $rc != 0;
    if $tests-only {
        # Only the files that could be tests: enough to see which invariants
        # have a test naming them, without writing a whole tree to disk.
        ($rc, $out, $err) = g($root, 'ls-tree', '-r', '--name-only', $tree);
        gate-error("cannot list tree $tree: {$err.trim.lines.head // ''}") if $rc != 0;
        my @paths = $out.lines.grep({ is-test-path($_) });
        for @paths.rotor(200, :partial) -> @some {
            ($rc, $, $err) = g($root, 'checkout-index', '-f', '--prefix=' ~ $dir.Str ~ '/', '--', |@some);
            gate-error("cannot check out test files of $tree: {$err.trim.lines.head // ''}") if $rc != 0;
        }
        return $dir;
    }
    ($rc, $, $err) = g($root, 'checkout-index', '-a', '-f', '--prefix=' ~ $dir.Str ~ '/');
    gate-error("cannot check out tree $tree: {$err.trim.lines.head // ''}") if $rc != 0;
    $dir;
}

#| Remove an exported tree.  A symbolic link is only ever unlinked, never
#| followed: the links made by link-environment point into the real
#| checkout, and nothing there may be touched.
sub rm-tree(IO::Path $dir) is export {
    return if $dir.l;                 # never descend through a link, whatever called us
    return unless $dir.e;
    for $dir.dir -> $e {
        if $e.l        { try $e.unlink }
        elsif $e.d     { rm-tree($e) }
        else           { try $e.unlink }
    }
    try $dir.rmdir;
}

#| The candidate's environment.  An exported tree holds the tracked files
#| and nothing else, so a test there finds no installed dependencies, no
#| local configuration, none of what .gitignore keeps out of Git.  Those
#| ignored files are not part of any candidate, they are the machine's
#| environment, so each is linked into the exported tree from the checkout:
#| the tracked files come from the snapshot, the environment from here.
#| Untracked files that are not ignored are left out on purpose: a commit
#| would not carry them either.  Returns how many were linked.
sub link-environment(IO::Path $root, IO::Path $dir --> Int) is export {
    my ($rc, $out, $) = g($root, 'ls-files', '--others', '--ignored', '--exclude-standard', '--directory');
    return 0 if $rc != 0;
    my $n = 0;
    for $out.lines.head(2000) -> $line {
        my $rel = $line.subst(/ '/' $/, '');
        next if $rel eq '' || $rel eq '.git' || $rel.starts-with('.git/');
        my $src = $root.add($rel);
        my $dst = $dir.add($rel);
        next if $dst.e || $dst.l || !$src.e;
        try $dst.parent.mkdir;
        $n++ if try $src.absolute.IO.symlink($dst);
    }
    $n;
}

# ----------------------------------------------------------- commitments

sub norm(Str $s --> Str) { ($s // '').words.join(' ') }

#| The numbers a base IZ4 has retired, from its withdrawal comments.
sub retired-numbers(Str $source --> Set) {
    $source.lines.map({ .match(/^ \s* '#' .* 'Invariant' \s+ (\d+) \s+ 'was withdrawn' /) })
           .grep(*.defined).map({ +.[0] }).Set;
}

#| What the candidate IZ4 commits to that the base did not, or no longer
#| does.  Each change is a hash with a kind and the exact before/after
#| wording.  Blocking kinds (invalid, foundation, reused-number) are
#| never approvable; the others need a person's agreement.
sub commitment-changes(IZ4::Document $base, IZ4::Document $cand, Str :$base-source = '' --> List) is export {
    my @c;
    without $cand {
        @c.push: %( kind => 'removed-file', detail => 'the IZ4 is gone from the candidate tree' ) if $base.defined;
        return @c;
    }
    @c.push: %( kind => 'invalid', detail => $cand.errors.map(*.Str).join('; ') ) unless $cand.ok;
    @c.push: %( kind => 'foundation', detail => $cand.foundation-status ) unless $cand.foundation-intact;

    my $bw = $base.defined ?? norm($base.for-what) !! '';
    my $cw = norm($cand.for-what);
    @c.push: %( kind => 'purpose', before => $bw, after => $cw ) if $bw ne $cw;
    my $bo = $base.defined ?? norm($base.for-who) !! '';
    my $co = norm($cand.for-who);
    @c.push: %( kind => 'people', before => $bo, after => $co ) if $bo ne $co;

    my %b = $base.defined ?? $base.invariants.grep(*.number.defined).map({ .number => $_ }) !! ();
    my %k = $cand.invariants.grep(*.number.defined).map({ .number => $_ });
    my $retired = retired-numbers($base-source);
    for %k.keys.sort(+*) -> $n {
        my $inv = %k{$n};
        if %b{$n}:exists {
            my $old = %b{$n};
            if norm($old.text) ne norm($inv.text) || norm($old.because) ne norm($inv.because) {
                @c.push: %( kind => 'revised', number => +$n,
                            before => norm($old.text), after => norm($inv.text),
                            before_because => norm($old.because), after_because => norm($inv.because) );
            }
        }
        elsif +$n ∈ $retired {
            @c.push: %( kind => 'reused-number', number => +$n, after => norm($inv.text),
                        detail => "Invariant $n was withdrawn before; a retired number is never reused (Invariant 13)" );
        }
        else {
            @c.push: %( kind => 'added', number => +$n, after => norm($inv.text), after_because => norm($inv.because) );
        }
    }
    for %b.keys.sort(+*) -> $n {
        next if %k{$n}:exists;
        @c.push: %( kind => 'removed', number => +$n, before => norm(%b{$n}.text), before_because => norm(%b{$n}.because) );
    }
    for $cand.unnumbered-invariants -> $inv {
        @c.push: %( kind => 'added', after => norm($inv.text), after_because => norm($inv.because),
                    detail => "unnumbered: 'iz4 number' gives it one" );
    }
    @c;
}

# ----------------------------------------------------------- protections

my regex skip-marker {
    :i [ 'skip' | 'todo' | 'xit(' | 'xdescribe(' | 'xtest(' | 'it.skip' | 'test.skip' | 'describe.skip'
       | 'pytest.mark.skip' | 'pytest.mark.xfail' | 't.Skip' | '#[ignore]' | 'plan skip_all' ]
}

#| What happened to the tests that name invariants, between the two
#| trees: removed, no longer naming the invariant, carrying a new skip
#| marker (weakened, as a suspicion), or merely changed.
sub protection-changes(IZ4::Document $base, IO::Path $base-dir, IZ4::Document $cand, IO::Path $cand-dir --> List) is export {
    return () without $base;
    return () without $cand;
    my %eb = evidence-for($base, $base-dir);
    my %ec = evidence-for($cand, $cand-dir);
    my @p;
    for %eb<state>.keys.sort(+*) -> $n {
        next unless %eb<state>{$n} eq 'named';
        next without $cand.invariant(+$n);                 # its removal is the commitment change
        my @before = |(%eb<files>{$n} // ());
        my @after  = |(%ec<files>{$n} // ());
        if (%ec<state>{$n} // 'none') ne 'named' {
            @p.push: %( kind => 'protection-removed', number => +$n, files => @before.List,
                        detail => "Invariant $n had a test naming it; the candidate has " ~ (%ec<state>{$n} // 'none') );
            next;
        }
        for @before -> $f {
            if $f ∉ @after {
                @p.push: %( kind => 'protection-unlinked', number => +$n, files => ($f,).List,
                            detail => "$f no longer names and quotes Invariant $n, or is gone" );
                next;
            }
            my $old = (try $base-dir.add($f).slurp) // '';
            my $new = (try $cand-dir.add($f).slurp) // '';
            next if $old eq $new;
            my $was = $old.lines.Set;
            my @added = $new.lines.grep({ $_ ∉ $was });
            my $skip = @added.first({ $_ ~~ &skip-marker });
            if $skip.defined {
                @p.push: %( kind => 'protection-weakened', number => +$n, files => ($f,).List,
                            detail => "$f gained a line that looks like a skip: " ~ $skip.trim.substr(0, 80) );
            }
            else {
                @p.push: %( kind => 'protection-changed', number => +$n, files => ($f,).List, detail => "$f changed; its check runs below" );
            }
        }
    }
    @p;
}

# ---------------------------------------------------------------- checks

#| How to run one test file, by the repository's test language.  Empty
#| when no runner is known: the check is then reported as unassessed
#| rather than skipped, and IZ4_CHECK_CMD (with {file}) names one.
sub runner-for(Str $lang, Str $file, IO::Path $dir --> List) {
    given $lang {
        when 'raku'   { ('raku', '-I', 'lib', $file) }
        when 'perl'   { ('perl', '-Ilib', |($dir.add('local/lib/perl5').d ?? ('-Ilocal/lib/perl5',) !! ()), $file) }
        when 'python' { ('python3', '-m', 'pytest', '-q', $file) }
        when 'ruby'   { ('ruby', '-Ilib', '-Itest', $file) }
        when 'go'     { ('go', 'test', './' ~ $file.IO.parent.Str) }
        when 'sh'     { ('sh', $file) }
        default       { () }
    }
}

#| The line that says a test could not start for want of a dependency, in
#| the languages the gate runs; Nil when the output shows nothing of the kind.
sub missing-dependency(Str $output --> Str) is export {
    for $output.lines -> $l {
        return $l.trim.substr(0, 160) if $l ~~ /
            "Can't locate " \S+ ' in @INC'               # Perl
          | 'Could not find ' \S+ ' in:'                  # Raku
          | 'ModuleNotFoundError' | 'No module named '    # Python
          | 'Cannot find module'                          # Node
          | 'cannot load such file'                       # Ruby
        /;
    }
    Str;
}

sub text-of(Blob $b --> Str) { (try $b.decode('utf8')) // $b.decode('latin-1') }

sub have-timeout(--> Bool) {
    my $p = try run 'timeout', '--version', :out, :err;
    return False without $p;
    $p.out.slurp(:close); $p.err.slurp(:close);
    $p.exitcode == 0;
}

#| Run the tests naming invariants from the candidate tree, each file
#| once, with a timeout where the system has one.  A test that cannot be
#| run is unassessed, never passed.
sub run-checks(IZ4::Document $cand, IO::Path $cand-dir, Int :$timeout = 300, Str :$cmd --> List) is export {
    return () without $cand;
    my %ec = evidence-for($cand, $cand-dir);
    my %by-file;
    for %ec<state>.keys -> $n {
        next unless %ec<state>{$n} eq 'named';
        %by-file{$_}.push(+$n) for |(%ec<files>{$n} // ());
    }
    my $lang = detect-language($cand-dir);
    my $has-timeout = have-timeout();
    # Inside a Git hook, Git exports where its index and repository are
    # (GIT_INDEX_FILE and friends).  A test that runs git itself must not
    # inherit them: it would read or write this repository's index.
    my %clean = %*ENV.grep({ .key ne any(<GIT_INDEX_FILE GIT_DIR GIT_WORK_TREE GIT_PREFIX GIT_COMMON_DIR
                                           GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE>) });
    my @out;
    for %by-file.keys.sort -> $f {
        my @argv = $cmd.defined
            ?? $cmd.subst('{file}', $f, :g).words
            !! runner-for($lang, $f, $cand-dir);
        my %r = file => $f, invariants => %by-file{$f}.sort.List, timeout_applied => $has-timeout;
        if !@argv {
            %r<outcome> = 'unassessed';
            %r<detail>  = "no runner known for $lang tests; set IZ4_CHECK_CMD, e.g. 'npm test -- \{file\}'";
            @out.push: %r;
            next;
        }
        my @run = $has-timeout ?? ('timeout', $timeout.Str, |@argv) !! @argv;
        my $p = try run |@run, :cwd($cand-dir.Str), :env(%clean), :out, :err, :bin;
        without $p {
            %r<outcome> = 'unassessed';
            %r<detail>  = "could not run {@argv[0]}: not found";
            @out.push: %r;
            next;
        }
        # a test may print anything; bytes that are not UTF-8 must not stop the gate
        my $o = text-of($p.out.slurp(:close));
        my $e = text-of($p.err.slurp(:close));
        if $has-timeout && $p.exitcode == 124 {
            %r<outcome> = 'timeout';
            %r<detail>  = "no result within {$timeout}s";
        }
        elsif $p.exitcode == 127 || ($p.exitcode != 0 && $o eq '' && $e.contains('not found')) {
            %r<outcome> = 'unassessed';
            %r<detail>  = "could not run {@argv[0]}: " ~ ($e.trim.lines.head // 'not found');
        }
        elsif $p.exitcode != 0 && missing-dependency($e ~ $o) -> $why {
            # the test never ran: its environment is incomplete.  That is a
            # gap in what the gate could look at, not a finding about the code.
            %r<outcome> = 'unassessed';
            %r<detail>  = "could not run: $why - install the project's dependencies where the gate runs";
        }
        else {
            %r<outcome> = $p.exitcode == 0 ?? 'passed' !! 'failed';
            # what went wrong, stderr first: the last lines of a test's standard output are usually its passing ones
            my @said = ($e.lines.grep(*.trim ne '').tail(3), $o.lines.grep(*.trim ne '').tail(2)).flat;
            %r<detail>  = $p.exitcode == 0 ?? '' !! @said.join(' | ').substr(0, 400);
        }
        @out.push: %r;
    }
    @out;
}

# -------------------------------------------------------------- proposal

#| What a person is asked to agree to: the commitment and protection
#| changes, bound to the repository, base and candidate trees.
sub proposal(%snap, @changes, @protections --> Hash) is export {
    %(
        schema      => PROPOSAL-SCHEMA,
        repository  => %snap<repository>,
        base        => %snap<base> // 'none',
        candidate   => %snap<candidate>,
        changes     => @changes.List,
        protections => @protections.grep({ .<kind> ne 'protection-changed' }).List,
    );
}

sub sha256-text(Str $s --> Str) {
    my $tmp = $*TMPDIR.add("iz4-gate-{$*PID}-{(^1_000_000).pick}.txt");
    LEAVE { try $tmp.unlink }
    $tmp.spurt($s);
    sha256-file($tmp);
}

#| The digest an approval binds to: the changes and protections only, so
#| the same proposal on the same trees always has the same digest.
sub proposal-digest(%p --> Str) is export {
    sha256-text(json-encode(%( changes => %p<changes>, protections => %p<protections> )));
}

sub needs-agreement(%p --> Bool) is export {
    so %p<changes>.grep({ .<kind> eq any(@AGREEMENT-KINDS) }) || %p<protections>.grep({ .<kind> eq any(@PROTECTION-AGREEMENT-KINDS) });
}

sub is-blocked(%p --> Bool) is export {
    so %p<changes>.grep({ .<kind> eq any(@BLOCKING-KINDS) });
}

#| The proposal as a person reads it.
sub proposal-lines(%p --> List) is export {
    my @l;
    for |%p<changes> -> %c {
        given %c<kind> {
            when 'purpose'  { @l.push: 'IS FOR WHAT changes', "  before: {%c<before> || '(none)'}", "  after:  {%c<after>}" }
            when 'people'   { @l.push: 'IS FOR WHO changes', "  before: {%c<before> || '(none)'}", "  after:  {%c<after>}" }
            when 'added'    {
                @l.push: "Invariant {%c<number> // '(unnumbered)'} added: {%c<after>}";
                @l.push: "  BECAUSE {%c<after_because>}" if %c<after_because>;
                @l.push: "  {%c<detail>}" if %c<detail>;
            }
            when 'revised'  {
                @l.push: "Invariant {%c<number>} revised";
                @l.push: "  before: {%c<before>}" ~ (%c<before_because> ?? " BECAUSE {%c<before_because>}" !! '');
                @l.push: "  after:  {%c<after>}" ~ (%c<after_because> ?? " BECAUSE {%c<after_because>}" !! '');
            }
            when 'removed'       { @l.push: "Invariant {%c<number>} removed: {%c<before>}" }
            when 'removed-file'  { @l.push: 'The IZ4 is removed: every commitment with it' }
            when 'invalid'       { @l.push: "BLOCKED: the candidate IZ4 does not parse: {%c<detail>}" }
            when 'foundation'    { @l.push: "BLOCKED: {%c<detail>}", '  Invariants 0-4 are the foundation; no project approval can change them (Invariant 4)' }
            when 'reused-number' { @l.push: "BLOCKED: {%c<detail>}" }
        }
    }
    for |%p<protections> -> %t {
        @l.push: "Protection of Invariant {%t<number>}: {%t<kind>.subst('protection-', '')} - {%t<detail>}";
    }
    @l;
}

# -------------------------------------------------------------- approval

#| An approval, bound to everything the agreement covers.  method is
#| 'terminal' (a person said yes at a terminal that ran iz4 approve) or
#| 'ssh-signature' (the same, signed with a key an acceptance boundary
#| can check against its allowed signers).
sub approval-body(%snap, Str $digest, Str :$by!, Str :$method!, Str :$note = '' --> Hash) is export {
    my %a =
        schema          => APPROVAL-SCHEMA,
        repository      => %snap<repository>,
        base            => %snap<base> // 'none',
        candidate       => %snap<candidate>,
        proposal_digest => $digest,
        approved_by     => $by,
        approved_at     => DateTime.now.utc.truncated-to('second').Str,
        method          => $method;
    %a<note> = $note if $note ne '';
    %a;
}

#| The bytes a signature covers: the approval without its signature field,
#| as canonical JSON (keys sorted).
sub signed-bytes(%approval --> Str) is export {
    my %body = %approval.grep({ .key ne 'signature' });
    json-encode(%body);
}

#| Sign with ssh-keygen -Y; returns the armoured signature.
sub sign-approval(%approval, IO::Path $key --> Str) is export {
    my $tmp = $*TMPDIR.add("iz4-approval-{$*PID}-{(^1_000_000).pick}");
    my $sig = ($tmp.Str ~ '.sig').IO;
    LEAVE { try $tmp.unlink; try $sig.unlink }
    $tmp.spurt(signed-bytes(%approval));
    my $p = try run 'ssh-keygen', '-Y', 'sign', '-f', $key.Str, '-n', SIGN-NAMESPACE, $tmp.Str, :out, :err;
    gate-error('ssh-keygen is needed to sign an approval and was not found') without $p;
    $p.out.slurp(:close);
    my $err = $p.err.slurp(:close);
    gate-error("ssh-keygen could not sign: {$err.trim.lines.head // ''}") if $p.exitcode != 0;
    $sig.slurp;
}

#| Verify a signature against an allowed-signers file (the sshd format:
#| principal, options, key).  Returns '' when it verifies, else why not.
sub verify-signature(%approval, IO::Path $approvers --> Str) is export {
    return 'the approval carries no signature' without %approval<signature>;
    return "allowed-signers file {$approvers} not found" unless $approvers.f;
    my $tag  = "iz4-verify-{$*PID}-{(^1_000_000).pick}";
    my $data = $*TMPDIR.add($tag);
    my $sig  = $*TMPDIR.add("$tag.sig");
    LEAVE { try $data.unlink; try $sig.unlink }
    $data.spurt(signed-bytes(%approval));
    $sig.spurt(%approval<signature>);
    my $p = try run 'ssh-keygen', '-Y', 'verify', '-f', $approvers.Str, '-I', %approval<approved_by>,
        '-n', SIGN-NAMESPACE, '-s', $sig.Str, :in, :out, :err;
    return 'ssh-keygen is needed to verify a signature and was not found' without $p;
    $p.in.print($data.slurp);
    my $ = try $p.in.close;
    my $out = $p.out.slurp(:close);
    my $err = $p.err.slurp(:close);
    $p.exitcode == 0 ?? '' !! "signature does not verify for {%approval<approved_by>}: " ~ (($err ~ $out).trim.lines.head // '');
}

#| Store an approval outside every tree: a blob under
#| refs/iz4/approvals/<candidate tree>.  Returns the ref name.
sub store-approval(IO::Path $root, %approval --> Str) is export {
    my $p = run 'git', '-C', $root.Str, 'hash-object', '-w', '--stdin', :in, :out, :err;
    $p.in.print(json-encode(%approval) ~ "\n");
    my $ = try $p.in.close;
    my $blob = $p.out.slurp(:close).trim;
    $p.err.slurp(:close);
    gate-error('git could not store the approval') unless $blob ~~ /^ <[0..9a..f]> ** 40..64 $/;
    my $ref = APPROVAL-REFS ~ %approval<candidate>;
    my ($rc, $, $err) = g($root, 'update-ref', $ref, $blob);
    gate-error("git could not write $ref: {$err.trim.lines.head // ''}") if $rc != 0;
    $ref;
}

sub json-unescape(Str $s --> Str) {
    $s.subst(/ '\\' (<[nrt"\\/]>) /, { given $0.Str { when 'n' { "\n" }; when 'r' { "\r" }; when 't' { "\t" }; default { $_ } } }, :g)
      .subst(/ '\\u' (<xdigit> ** 4) /, { chr(:16($0.Str)) }, :g);
}

#| Read an approval: from a file when given, else from the ref for this
#| candidate tree.  An empty hash when there is none; a hash with
#| 'malformed' when there is one that cannot be read.
sub load-approval(IO::Path $root, Str $candidate, IO::Path :$file --> Hash) is export {
    my $text;
    with $file {
        return %( malformed => "approval file {$file} not found" ) unless $file.f;
        $text = try $file.slurp;
        return %( malformed => "approval file {$file} is not readable text" ) without $text;
    }
    else {
        my ($rc, $out, $) = g($root, 'cat-file', '-p', APPROVAL-REFS ~ $candidate);
        return %() if $rc != 0;
        $text = $out;
    }
    return %( malformed => 'approval is not an iz4-approval/1 document' )
        unless (json-field($text, 'schema') // '') eq APPROVAL-SCHEMA;
    my %a;
    for <schema repository base candidate proposal_digest approved_by approved_at method note signature> -> $k {
        my $v = json-field($text, $k);
        %a{$k} = json-unescape($v) with $v;
    }
    for <repository base candidate proposal_digest approved_by method> -> $k {
        return %( malformed => "approval lacks $k" ) unless %a{$k}:exists;
    }
    %a;
}

#| Does this approval cover this proposal, here, now?  Returns a hash:
#| valid, level ('signed' | 'terminal' | 'none'), reasons.  Under
#| :enforce only a signature by an allowed signer counts.
sub validate-approval(%approval, %snap, Str $digest, IO::Path :$approvers, Bool :$enforce = False --> Hash) is export {
    my @why;
    with %approval<malformed> { return %( valid => False, level => 'none', reasons => ($_,).List ) }
    @why.push: "approval is for another repository ({%approval<repository>.substr(0, 12)})" if %approval<repository> ne %snap<repository>;
    @why.push: "approval was for base {%approval<base>.substr(0, 12)}, this base is {(%snap<base> // 'none').substr(0, 12)}: rebased or merged, so agree again"
        if %approval<base> ne (%snap<base> // 'none');
    @why.push: "approval was for tree {%approval<candidate>.substr(0, 12)}, the candidate is {%snap<candidate>.substr(0, 12)}: the tree changed after approval"
        if %approval<candidate> ne %snap<candidate>;
    @why.push: 'approval was for a different proposal: the commitment or protection changes differ' if %approval<proposal_digest> ne $digest;
    return %( valid => False, level => 'none', reasons => @why.List ) if @why;

    if %approval<signature>:exists {
        without $approvers {
            return %( valid => !$enforce, level => ($enforce ?? 'none' !! 'terminal'),
                      reasons => ('signed, but no allowed-signers file was given (--approvers or IZ4_APPROVERS), so the signature was not checked',).List );
        }
        my $bad = verify-signature(%approval, $approvers);
        return %( valid => False, level => 'none', reasons => ($bad,).List ) if $bad ne '';
        return %( valid => True, level => 'signed', reasons => () );
    }
    return %( valid => False, level => 'none',
              reasons => ("a terminal approval by {%approval<approved_by>} is not accepted under --enforce: an acceptance boundary needs an approval signed by an allowed signer",).List )
        if $enforce;
    %( valid => True, level => 'terminal', reasons => () );
}

# ------------------------------------------------------------------ gate

#| The whole gate: snapshots, the two diffs, the checks, the approval,
#| the outcome.  Returns the iz4-gate/1 result as a hash; an operational
#| error is an exception the caller turns into that outcome.
sub run-gate(IO::Path $root, Bool :$staged = False, Str :$base, Str :$candidate, Bool :$enforce = False,
             Bool :$checks = True, Int :$timeout = 300, Str :$check-cmd, IO::Path :$approval-file, IO::Path :$approvers
             --> Hash) is export {
    my %snap = snapshots($root, :$staged, :$base, :$candidate);
    my $base-src = %snap<base>.defined ?? tree-file($root, %snap<base>, ROOT-NAME) !! Str;
    my $cand-src = tree-file($root, %snap<candidate>, ROOT-NAME);
    my $base-doc = $base-src.defined ?? IZ4::Document.parse($base-src) !! IZ4::Document;
    my $cand-doc = $cand-src.defined ?? IZ4::Document.parse($cand-src) !! IZ4::Document;

    my %r =
        schema        => GATE-SCHEMA,
        tool          => "iz4/{VERSION}",
        mode          => ($enforce ?? 'enforce' !! 'advisory'),
        repository    => %snap<repository>,
        selection     => %snap<selection>,
        base          => %snap<base> // 'none',
        base_ref      => %snap<base_ref>,
        candidate     => %snap<candidate>,
        candidate_ref => %snap<candidate_ref>,
        iz4           => %( base_present => $base-src.defined, candidate_present => $cand-src.defined );

    if !$cand-src.defined && !$base-src.defined {
        %r<changes> = (); %r<protections> = (); %r<checks> = (); %r<touches> = ();
        %r<proposal_digest> = '';
        %r<approval>  = %( status => 'not-needed' );
        %r<outcome>   = 'pass';
        %r<notes>     = ('no IZ4 in either tree: nothing is committed to here',).List;
        %r<exit_code> = 0;
        %r<next>      = ();
        return %r;
    }

    my @changes = commitment-changes($base-doc, $cand-doc, :base-source($base-src // ''));
    my ($base-dir, $cand-dir);
    my $linked = 0;
    my $skipped = 0;
    my @protections;
    my @checks;
    my @touches;
    {
        LEAVE { rm-tree($_) with $base-dir; rm-tree($_) with $cand-dir }
        # First only the test files of each tree: enough to see which
        # invariants have a test naming them and what happened to those
        # tests.  The whole candidate tree is written out only when there
        # is a check to run in it.
        $cand-dir = export-tree($root, %snap<candidate>, :tests-only);
        if %snap<base>.defined && $base-doc.defined && $cand-doc.defined {
            $base-dir = export-tree($root, %snap<base>, :tests-only);
            @protections = protection-changes($base-doc, $base-dir, $cand-doc, $cand-dir);
        }
        my $named = $cand-doc.defined && $cand-doc.ok
            ?? +evidence-for($cand-doc, $cand-dir)<state>.values.grep(* eq 'named') !! 0;
        if $checks && $named {
            rm-tree($cand-dir);
            $cand-dir = export-tree($root, %snap<candidate>);
            $linked = link-environment($root, $cand-dir);
            @checks = run-checks($cand-doc, $cand-dir, :$timeout, :cmd($check-cmd));
        }
        elsif !$checks {
            # --no-checks: how many linked tests went unrun, so that skipping
            # nothing is a pass and skipping something is never one
            $skipped = $named;
        }
        if %snap<base>.defined && $cand-doc.defined {
            my ($rc, $diff, $) = g($root, 'diff', '--no-color', %snap<base>, %snap<candidate>);
            @touches = touched-invariants($cand-doc, $diff).map({ %( number => .<number>, terms => .<terms>.List ) }) if $rc == 0;
        }
    }
    my %p = proposal(%snap, @changes, @protections);
    my $digest = proposal-digest(%p);
    %r<changes>     = @changes.List;
    %r<protections> = @protections.List;
    %r<checks>      = @checks.List;
    %r<touches>     = @touches.List;
    %r<proposal_digest> = $digest;
    %r<environment_links> = $linked;

    my @notes;
    my @next;
    my $blocked    = is-blocked(%p) || ?@checks.grep({ .<outcome> eq 'failed' });
    my $agree      = needs-agreement(%p);
    my $unassessed = ?@checks.grep({ .<outcome> eq any(<timeout unassessed>) });
    if $skipped {
        @notes.push: "checks were not run (--no-checks): $skipped invariant{$skipped == 1 ?? ' has' !! 's have'} a test naming {$skipped == 1 ?? 'it' !! 'them'}, unassessed here";
        $unassessed = True;
    }

    # the approval, if any
    my %approval = load-approval($root, %snap<candidate>, :file($approval-file));
    if $agree && !$blocked {
        if %approval {
            my %v = validate-approval(%approval, %snap, $digest, :$approvers, :$enforce);
            %r<approval> = %( status => (%v<valid> ?? 'valid' !! 'invalid'), level => %v<level>,
                              approved_by => %approval<approved_by> // '', approved_at => %approval<approved_at> // '',
                              method => %approval<method> // '', reasons => %v<reasons> );
            $agree = False if %v<valid>;
        }
        else {
            %r<approval> = %( status => 'missing', level => 'none', reasons => ('no approval for this candidate tree',).List );
        }
    }
    else {
        %r<approval> = %( status => ($blocked ?? 'not-applicable' !! 'not-needed') );
    }

    my $outcome = $blocked ?? 'blocked' !! $agree ?? 'agreement-required' !! $unassessed ?? 'unassessed' !! 'pass';
    %r<outcome>   = $outcome;
    %r<exit_code> = $enforce ?? %EXIT-CODE{$outcome} !! 0;

    given $outcome {
        when 'blocked' {
            @next.push: 'iz4 foundation --restore' if @changes.grep({ .<kind> eq 'foundation' });
            @next.push: 'iz4 check' if @changes.grep({ .<kind> eq 'invalid' });
            @next.push: "give the invariant a new number: 'iz4 number'" if @changes.grep({ .<kind> eq 'reused-number' });
            @next.push: "make {.<file>} pass, or if the invariant no longer holds, change the IZ4 and its test together and seek agreement" for @checks.grep({ .<outcome> eq 'failed' });
        }
        when 'agreement-required' {
            my $sign = $enforce ?? ' --sign=<key> --by=<principal>' !! '';
            @next.push: %snap<selection> eq 'staged'
                ?? "iz4 approve --staged$sign"
                !! "iz4 approve --candidate={%snap<candidate_ref>}" ~ (%snap<base_ref> eq 'none' ?? ' --base=none' !! "") ~ $sign;
            @next.push: 'git push origin ' ~ APPROVAL-REFS ~ %snap<candidate> ~ '   (so the acceptance boundary can fetch the approval)' if $enforce;
        }
        when 'unassessed' {
            for @checks.grep({ .<outcome> eq any(<timeout unassessed>) }) {
                @next.push: .<outcome> eq 'timeout' ?? "run {.<file>} yourself, or raise --timeout"
                    !! .<detail>.starts-with('could not run: ') ?? "install the project's dependencies so {.<file>} can run"
                    !! "set IZ4_CHECK_CMD or --check-cmd so {.<file>} can run";
            }
            @next.push: 'run iz4 gate without --no-checks' unless $checks;
        }
    }
    %r<notes> = @notes.List;
    %r<next>  = @next.List;
    %r;
}

# ------------------------------------------------------------------ hook

constant GATE-HOOK-MARK is export = '# iz4 gate hook';

#| The pre-commit hook: the gate on the staged tree.  Advisory unless
#| written with :enforce.
sub gate-hook-text(Bool :$enforce = False --> Str) is export {
    qq:to/END/;
    #!/bin/sh
    {GATE-HOOK-MARK} (written by 'iz4 gate --install-hook'; delete this file to remove it)
    command -v iz4 >/dev/null 2>&1 || exit 0
    {$enforce ?? 'iz4 gate --staged --enforce' !! 'iz4 gate --staged; exit 0'}
    END
}
