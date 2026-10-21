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
#|                 invalid or gone, a retired name reused, or a file
#|                 going back to an earlier form.
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
#| file, which the candidate cannot edit.  The foundation is never
#| approvable: altering it is blocked.
#|
#| An invariant is compared by its name and nothing else.  Where it sits
#| in the file is presentation: moving it changes no commitment.  The
#| same name with different words is a revision.  A new name is a new
#| commitment, even with the same words, and the old name's going is a
#| withdrawal: both are shown, and a person agrees to both.
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

constant GATE-SCHEMA     is export = 'iz4-gate/2';
constant PROPOSAL-SCHEMA is export = 'iz4-proposal/2';
constant APPROVAL-SCHEMA is export = 'iz4-approval/1';
constant APPROVAL-REFS   is export = 'refs/iz4/approvals/';
constant SIGN-NAMESPACE  is export = 'iz4-approval';

#| The outcomes, and the exit code each has under --enforce.  Advisory
#| mode prints the same outcome and exits 0 for all but error.
constant %EXIT-CODE is export = (pass => 0, error => 1, 'agreement-required' => 2, blocked => 3, unassessed => 4);
constant @REJECTS   is export = <agreement-required blocked unassessed error>;

constant @BLOCKING-KINDS  = <invalid foundation reused-name format-regressed>;
constant @AGREEMENT-KINDS = <purpose people added revised removed removed-file named foundation-migrated reach-added mode protection>;
constant @PROTECTION-AGREEMENT-KINDS = <protection-removed protection-unlinked protection-weakened protection-rewritten>;

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
    # Git is pointed at a temporary index through the environment of these
    # calls alone.  The process's own environment is never changed: a
    # GIT_INDEX_FILE left set would send every later git command, here or
    # in a linked test, to an index that is not the repository's.
    my %env = %*ENV, GIT_INDEX_FILE => $index.Str;
    my &gi = sub (*@args) {
        my $p = try run 'git', '-C', $root.Str, |@args, :out, :err, :%env;
        return (127, '', 'git is not installed or cannot be run') without $p;
        my $o = $p.out.slurp(:close);
        my $e = $p.err.slurp(:close);
        ($p.exitcode, $o, $e);
    };
    my ($rc, $out, $err) = gi('read-tree', $tree);
    try $index.unlink if $rc != 0;
    gate-error("cannot read tree $tree: {$err.trim.lines.head // ''}") if $rc != 0;
    if $tests-only {
        # Only the files that could be tests: enough to see which invariants
        # have a test naming them, without writing a whole tree to disk.
        ($rc, $out, $err) = gi('ls-tree', '-r', '--name-only', $tree);
        my @paths = $rc == 0 ?? $out.lines.grep({ is-test-path($_) }) !! ();
        my $bad = $rc != 0 ?? "cannot list tree $tree: {$err.trim.lines.head // ''}" !! '';
        for @paths.rotor(200, :partial) -> @some {
            last if $bad;
            ($rc, $, $err) = gi('checkout-index', '-f', '--prefix=' ~ $dir.Str ~ '/', '--', |@some);
            $bad = "cannot check out test files of $tree: {$err.trim.lines.head // ''}" if $rc != 0;
        }
        try $index.unlink;
        gate-error($bad) if $bad;
        return $dir;
    }
    ($rc, $, $err) = gi('checkout-index', '-a', '-f', '--prefix=' ~ $dir.Str ~ '/');
    try $index.unlink;
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

#| Sort identities the way a person reads them: alphabetically.
sub by-identity(@ids --> List) { @ids.sort({ $_ ~~ /^ \d+ $/ ?? (0, +$_, '') !! (1, 0, $_) }).List }

#| How a base's invariants correspond to a candidate's: identity => identity.
#| The same name is the same invariant.
sub correspondence(IZ4::Document $base, IZ4::Document $cand --> Hash) is export {
    my %m;
    return %m unless $base.defined && $cand.defined;
    my @b = $base.invariants.grep(*.id.defined);
    my @c = $cand.invariants.grep(*.id.defined);
    for @b -> $old { %m{$old.id} = $old.id if @c.first({ .id eq $old.id }).defined }
    %m;
}

#| What the candidate IZ4 commits to that the base did not, or no longer
#| does.  Each change is a hash with a kind, the invariant's identity and
#| the exact before/after wording.  Blocking kinds (invalid, foundation,
#| reused-name, format-regressed) are never approvable; the others need a
#| person's agreement.
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

    my $clauses-migrating = $base.defined && $base.form eq 'named' && $cand.form eq 'clauses';
    if $base.defined && $base.form eq 'clauses' && $cand.form ne 'clauses' {
        @c.push: %( kind => 'format-regressed',
                    detail => 'the candidate goes back to an earlier form; the base states each invariant in three clauses (WHERE, ALWAYS, PROTECTS), and a file only moves forward' );
        return @c;
    }
    if $clauses-migrating && $cand.foundation-intact {
        @c.push: %( kind => 'foundation-migrated',
                    title  => 'The foundation moves to the three-clause form: WHERE, ALWAYS and PROTECTS',
                    before => "the named foundation (sha256 {FOUNDATION-DIGEST.substr(0, 12)})",
                    after  => "{foundation-ids(:clauses).join(', ')} (sha256 {FOUNDATION-CLAUSES-DIGEST.substr(0, 12)})",
                    detail => 'read the words: each says where it applies (WHERE), what must always remain true there, and what must not be defeated (PROTECTS); every protection of the named foundation is kept, and the last is named binding.iz4.you' );
    }

    my %b = $base.defined ?? $base.invariants.grep(*.id.defined).map({ .id => $_ }) !! ();
    my %k = $cand.invariants.grep(*.id.defined).map({ .id => $_ });
    my %map = correspondence($base, $cand);
    my @retired = $base.defined ?? |$base.retired !! ();
    my @order = by-identity(%k.keys);
    for @order -> $id {
        my $inv = %k{$id};
        my $digest = invariant-digest($id, $inv.text, $inv.because, :reach($inv.reach));
        if %b{$id}:exists {
            my $old = %b{$id};
            my $reach-changed = !$clauses-migrating && norm($old.reach // '') ne norm($inv.reach // '');
            if norm($old.text) ne norm($inv.text) || norm($old.because) ne norm($inv.because) || $reach-changed {
                my %rev = kind => 'revised', :$id,
                            before => norm($old.text), after => norm($inv.text),
                            before_because => norm($old.because), after_because => norm($inv.because),
                            before_digest => invariant-digest($id, $old.text, $old.because, :reach($old.reach)), after_digest => $digest;
                if $inv.reach.defined { %rev<before_reach> = norm($old.reach // ''); %rev<after_reach> = norm($inv.reach) }
                @c.push: %rev;
            }
            elsif $clauses-migrating {
                @c.push: %( kind => 'reach-added', :$id, after_reach => norm($inv.reach), after => norm($inv.text),
                            after_because => norm($inv.because),
                            before_digest => invariant-digest($id, $old.text, $old.because), after_digest => $digest );
            }
        }
        elsif @retired.first(* eq $id).defined {
            @c.push: %( kind => 'reused-name', :$id, after => norm($inv.text),
                        detail => "INVARIANT $id was withdrawn before; a retired name is never given to a different invariant" );
        }
        else {
            my %add = kind => 'added', :$id, after => norm($inv.text), after_because => norm($inv.because), :$digest;
            %add<after_reach> = norm($inv.reach) if $inv.reach.defined;
            # the same words under a new name: say so, and still treat it as new
            my $twin = %b.values.first({ !(%k{.id}:exists) && norm(.text) eq norm($inv.text) });
            %add<detail> = "the same words as {$twin.id}, which this change removes: a new name is a new commitment, not a rename"
                if $twin.defined && !$clauses-migrating;
            @c.push: %add;
        }
    }
    for by-identity(%b.keys) -> $id {
        next if %map{$id}:exists;
        @c.push: %( kind => 'removed', :$id, before => norm(%b{$id}.text), before_because => norm(%b{$id}.because),
                    |(%b{$id}.reach.defined ?? (before_reach => norm(%b{$id}.reach)) !! ()) );
    }
    for $cand.unnamed-invariants -> $inv {
        @c.push: %( kind => 'added', after => norm($inv.text), after_because => norm($inv.because),
                    detail => 'it has no name yet' );
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
#| A test file without its comments and layout: what it asserts.  Two
#| files with the same substance differ only in comments or whitespace, so
#| a tidy is not a question; a change to what is asserted is.
sub substance(Str $text --> Str) {
    $text.lines.map(*.trim).grep({ $_ ne '' && !.starts-with('#') }).map({ .subst(/\s+/, ' ', :g) }).join("\n")
}

sub protection-changes(IZ4::Document $base, IO::Path $base-dir, IZ4::Document $cand, IO::Path $cand-dir --> List) is export {
    return () without $base;
    return () without $cand;
    my %eb = evidence-for($base, $base-dir);
    my %ec = evidence-for($cand, $cand-dir);
    my %map = correspondence($base, $cand);
    my @p;
    for by-identity(%eb<state>.keys) -> $was {
        next unless %eb<state>{$was} eq 'named';
        my $id = %map{$was} // next;                        # its removal is the commitment change
        my @before = |(%eb<files>{$was} // ());
        my @after  = |(%ec<files>{$id} // ());
        if (%ec<state>{$id} // 'none') ne 'named' {
            @p.push: %( kind => 'protection-removed', :$id, files => @before.List,
                        detail => "INVARIANT $id had a test naming it; the candidate has " ~ (%ec<state>{$id} // 'none') );
            next;
        }
        for @before -> $f {
            if $f ∉ @after {
                @p.push: %( kind => 'protection-unlinked', :$id, files => ($f,).List,
                            detail => "$f no longer names $id, or is gone" );
                next;
            }
            my $old = (try $base-dir.add($f).slurp) // '';
            my $new = (try $cand-dir.add($f).slurp) // '';
            next if $old eq $new;
            my $was-lines = $old.lines.Set;
            my @added = $new.lines.grep({ $_ ∉ $was-lines });
            my $skip = @added.first({ $_ ~~ &skip-marker });
            if $skip.defined {
                @p.push: %( kind => 'protection-weakened', :$id, files => ($f,).List,
                            detail => "$f gained a line that looks like a skip: " ~ $skip.trim.substr(0, 80) );
            }
            elsif substance($old) ne substance($new) {
                @p.push: %( kind => 'protection-rewritten', :$id, files => ($f,).List,
                            detail => "the assertions in $f changed; whether it still protects $id is for a person to say" );
            }
            else {
                @p.push: %( kind => 'protection-changed', :$id, files => ($f,).List, detail => "$f changed in comments or layout only; its check runs below" );
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

#| Is this command there to run?  A name with a slash is a path; a bare
#| name is looked for along PATH (with the usual suffixes on Windows).
#| Asked before a check is started, so that a runner that is not installed
#| is reported as exactly that on every system, whatever its shell or
#| 'timeout' would have made of it.
sub have-command(Str $name --> Bool) is export {
    my @suffix = $*DISTRO.is-win ?? ('', '.exe', '.cmd', '.bat') !! ('',);
    if $name.contains('/') || $name.contains('\\') {
        return so @suffix.grep({ ($name ~ $_).IO.f });     # grep, not first: the matching suffix may be ''
    }
    my $sep = $*DISTRO.is-win ?? ';' !! ':';
    for (%*ENV<PATH> // '').split($sep).grep(*.chars) -> $dir {
        return True if @suffix.grep({ $dir.IO.add($name ~ $_).f });
    }
    False;
}

sub have-timeout(--> Bool) {
    return False if %*ENV<IZ4_NO_TIMEOUT>;      # macOS ships none; this lets any system take that path
    my $p = try run 'timeout', '--version', :out, :err;
    return False without $p;
    $p.out.slurp(:close); $p.err.slurp(:close);
    $p.exitcode == 0;
}

#| Run the tests naming invariants from the candidate tree, each file
#| once, with a timeout where the system has one.  A test that cannot be
#| run is unassessed, never passed.
sub run-checks(IZ4::Document $cand, IO::Path $cand-dir, Int :$timeout = 300, Str :$cmd, Int :$jobs = check-jobs() --> List) is export {
    return () without $cand;
    my %ec = evidence-for($cand, $cand-dir);
    my %by-file;
    for %ec<state>.keys -> $n {
        next unless %ec<state>{$n} eq 'named';
        %by-file{$_}.push(~$n) for |(%ec<files>{$n} // ());
    }
    my $lang = detect-language($cand-dir);
    my $has-timeout = have-timeout();
    # Inside a Git hook, Git exports where its index and repository are
    # (GIT_INDEX_FILE and friends).  A test that runs git itself must not
    # inherit them: it would read or write this repository's index.
    my %clean = %*ENV.grep({ .key ne any(<GIT_INDEX_FILE GIT_DIR GIT_WORK_TREE GIT_PREFIX GIT_COMMON_DIR
                                           GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE>) });
    my sub check-one(Str $f --> Hash) {
        my @argv = $cmd.defined
            ?? $cmd.subst('{file}', $f, :g).words
            !! runner-for($lang, $f, $cand-dir);
        my %r = file => $f, invariants => by-identity(%by-file{$f}), timeout_applied => $has-timeout;
        if !@argv {
            %r<outcome> = 'unassessed';
            %r<detail>  = "no runner known for $lang tests; set IZ4_CHECK_CMD, e.g. 'npm test -- \{file\}'";
            return %r;
        }
        unless have-command(@argv[0]) {
            %r<outcome> = 'unassessed';
            %r<detail>  = "could not run {@argv[0]}: not found";
            return %r;
        }
        my @run = $has-timeout ?? ('timeout', $timeout.Str, |@argv) !! @argv;
        my $p = try run |@run, :cwd($cand-dir.Str), :env(%clean), :out, :err, :bin;
        without $p {
            %r<outcome> = 'unassessed';
            %r<detail>  = "could not run {@argv[0]}: not found";
            return %r;
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
        %r;
    }
    # The tests are independent of one another, so they run a few at a
    # time; the results come back in file order whatever finished first.
    my @files = %by-file.keys.sort;
    my @out;
    for @files.batch($jobs max 1) -> @batch {
        @out.append: await @batch.map(-> $f { start { check-one($f) } });
    }
    @out;
}

#| How many protecting tests run at once: IZ4_JOBS, else one.  Running
#| them in parallel under Raku++ produced an intermittent 'error' outcome
#| from the gate in the benchmark (one run in about a hundred), and a gate
#| that sometimes errs is worse than one that is sometimes slow; 'iz4
#| status' reuses a run while the tree is unchanged, so the cost is paid
#| once per change.  IZ4_JOBS=8 opts in.
sub check-jobs(--> Int) is export {
    my $j = %*ENV<IZ4_JOBS> // '';
    $j ~~ /^ \d+ $/ && $j > 0 ?? $j.Int !! 1;
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

#| An identity as a person reads it in a proposal: INVARIANT and its name.
sub shown($id --> Str) {
    !$id.defined ?? 'INVARIANT (unnamed)' !! "INVARIANT $id";
}

#| The proposal as a person reads it.
sub proposal-lines(%p --> List) is export {
    my @l;
    for |%p<changes> -> %c {
        given %c<kind> {
            when 'purpose'  { @l.push: 'IS FOR WHAT changes', "  before: {%c<before> || '(none)'}", "  after:  {%c<after>}" }
            when 'protection' { @l.push: "{shown(%c<id>)}: its protection changes", "  before: {%c<before>}", "  after:  {%c<after>}", "  {%c<detail>}" }
            when 'people'   { @l.push: 'IS FOR WHO changes', "  before: {%c<before> || '(none)'}", "  after:  {%c<after>}" }
            when 'added'    {
                @l.push: "{shown(%c<id>)} added: {%c<after>}";
                @l.push: "  WHERE {%c<after_reach>}" if %c<after_reach>;
                @l.push: "  {%c<after_reach>.defined ?? 'PROTECTS' !! 'BECAUSE'} {%c<after_because>}" if %c<after_because>;
                @l.push: "  {%c<detail>}" if %c<detail>;
            }
            when 'revised'  {
                @l.push: "{shown(%c<id>)} revised";
                @l.push: "  before: {%c<before>}" ~ (%c<before_because> ?? " BECAUSE {%c<before_because>}" !! '');
                @l.push: "  after:  {%c<after>}" ~ (%c<after_because> ?? " BECAUSE {%c<after_because>}" !! '');
                @l.push: "  WHERE before: {%c<before_reach> || '(none)'}", "  WHERE after:  {%c<after_reach>}" if %c<after_reach>.defined && %c<before_reach> ne %c<after_reach>;
            }
            when 'removed'       { @l.push: "{shown(%c<id>)} removed: {%c<before>}" }
            when 'reach-added'   { @l.push: "{shown(%c<id>)} gains its WHERE: {%c<after_reach>}", "  its ALWAYS and PROTECTS are word for word as before" }
            when 'foundation-migrated' {
                @l.push: (%c<title> // 'The foundation moves to named invariants, with new words'), "  before: {%c<before>}", "  after:  {%c<after>}", "  {%c<detail>}";
            }
            when 'removed-file'  { @l.push: 'The IZ4 is removed: every commitment with it' }
            when 'mode'          { @l.push: (%c<after> eq 'vibe' ?? 'The IZ4 goes into vibe mode' !! 'The IZ4 becomes solid'), "  {%c<detail>}" }
            when 'invalid'       { @l.push: "To put right: the candidate IZ4 does not parse: {%c<detail>}" }
            when 'foundation'    { @l.push: "To put right: {%c<detail>}", '  The foundation is the same in every IZ4; no project approval can change it (keystone.iz4.you)' }
            when 'reused-name' | 'format-regressed' { @l.push: "To put right: {%c<detail>}" }
        }
    }
    for |%p<protections> -> %t {
        @l.push: "Protection of {%t<id>}: {%t<kind>.subst('protection-', '')} - {%t<detail>}";
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

#| A leading ~ as a shell would have read it: a person who types
#| --sign=~/.ssh/key means their home directory.
sub home-path(Str $path --> IO::Path) is export {
    ($path.starts-with('~/') ?? $*HOME.add($path.substr(2)) !! $path.IO);
}

#| The allowed-signers file an approval will be judged against here:
#| the one named, else IZ4_APPROVERS, else the machine's own.
sub approvers-file(IO::Path $given? --> IO::Path) is export {
    return $given if $given.defined;
    with %*ENV<IZ4_APPROVERS> { return home-path($_) if .trim ne '' }
    my $own = $*HOME.add('.config/iz4/allowed_signers');
    $own.f ?? $own !! IO::Path;
}

# The public half of a key: the .pub beside it, or asked of ssh-keygen
# with an empty passphrase so it never stops to ask for one.
sub public-half(IO::Path $key --> Str) {
    my $pub = ($key.Str ~ '.pub').IO;
    return ($pub.slurp.words[1] // '') if $pub.f;
    my $p = try run 'ssh-keygen', '-y', '-P', '', '-f', $key.Str, :out, :err;
    return '' without $p;
    my $out = $p.out.slurp(:close); $p.err.slurp(:close);
    $p.exitcode == 0 ?? ($out.words[1] // '') !! '';
}

#| Who signs here, found so a person never has to say: the key and name
#| used last time (git config iz4.approveKey, iz4.approveAs), else the
#| key of their own that the allowed-signers file already lists, under
#| the name it lists it by.  Returns key, by and found (how), or nothing.
sub find-signer(IO::Path $root, IO::Path :$approvers --> Hash) is export {
    my $anchor = $root.add(ROOT-NAME);
    my ($rc, $key, $) = git($anchor, 'config', 'iz4.approveKey');
    my ($rc2, $as, $) = git($anchor, 'config', 'iz4.approveAs');
    if $rc == 0 && $rc2 == 0 && $key.trim ne '' && $as.trim ne '' && home-path($key.trim).f {
        return %( key => home-path($key.trim), by => $as.trim, found => 'as last time' );
    }
    my $file = approvers-file($approvers);
    my $dir  = (%*ENV<IZ4_SSH_DIR> // '') ne '' ?? %*ENV<IZ4_SSH_DIR>.IO !! $*HOME.add('.ssh');
    return %() unless $file.defined && $file.f && $dir.d;
    my %listed;                     # public key => the name it is listed under
    for $file.lines.grep({ .trim ne '' && !.starts-with('#') }) -> $l {
        my @w = $l.words;
        my $at = @w.first({ .starts-with('ssh-') || .starts-with('ecdsa-') || .starts-with('sk-') }, :k);
        %listed{@w[$at + 1]} //= @w[0].split(',')[0] if $at.defined && @w[$at + 1].defined;
    }
    for $dir.dir.grep({ .f && .extension ne 'pub' }).sort(*.basename) -> $k {
        next unless (try $k.lines.head // '') ~~ / 'PRIVATE KEY' /;
        my $pub = public-half($k);
        return %( key => $k, by => %listed{$pub}, found => "listed in {$file}" ) if $pub ne '' && (%listed{$pub}:exists);
    }
    %();
}

#| Remember who signed and with what, so the next approval asks nothing.
sub remember-signer(IO::Path $root, IO::Path $key, Str $by) is export {
    my $anchor = $root.add(ROOT-NAME);
    git($anchor, 'config', '--global', 'iz4.approveKey', $key.absolute);
    git($anchor, 'config', '--global', 'iz4.approveAs', $by);
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
    # The mode is the file's own to declare, and so is a stronger protection
    # written after one invariant's name.  What governs a change is what the
    # base declared: the candidate cannot lower a protection and use the lower
    # one in the same step.  Going from one mode to another, for the file or
    # for one invariant, is a change a person agrees to like any other, except
    # that protecting more in a settling file is free: only lowering costs a yes.
    my $cand-mode = $cand-doc.defined && $cand-doc.ok ?? $cand-doc.mode !! 'solid';
    my $base-mode = $base-doc.defined && $base-doc.ok ?? $base-doc.mode !! Str;
    my %rank = vibe => 0, firm => 1, solid => 2;
    my sub governing(Str $id --> Str) {
        return $base-doc.protection-of($id) if $base-doc.defined && $base-doc.ok;
        $cand-doc.defined && $cand-doc.ok ?? $cand-doc.protection-of($id) !! 'solid';
    }
    if $base-doc.defined && $cand-doc.defined && $base-doc.ok && $cand-doc.ok {
        if $base-mode ne $cand-mode {
            my $own = $cand-doc.invariants.grep(*.id.defined).elems;
            my %say = vibe => "its $own invariant{$own == 1 ?? '' !! 's'} go back to settling: changes to them will not wait for a yes until it is solid again",
                      firm => "its $own invariant{$own == 1 ?? '' !! 's'} become firm: from now on a change to any of them waits for a yes; a failing test is reported, not held",
                      solid => "its $own invariant{$own == 1 ?? '' !! 's'} become solid: from now on a change to any of them waits for a yes, and a failing test holds";
            @changes.push: %( kind => 'mode', before => $base-mode, after => $cand-mode, detail => %say{$cand-mode} );
        }
        # one invariant's own protection, raised or lowered
        for $cand-doc.invariants.grep(*.id.defined) -> $inv {
            next without $base-doc.invariant($inv.id);
            my ($was, $now) = $base-doc.invariant($inv.id).protection // '', $inv.protection // '';
            next if $was eq $now;
            @changes.push: %( kind => 'protection', id => $inv.id, before => ($was || "the file's mode, $base-mode"), after => ($now || "the file's mode, $cand-mode"),
                              detail => (%rank{$now || $cand-mode} < %rank{$was || $base-mode}
                                  ?? "its protection is lowered: this waits for a yes at the level it had"
                                  !! "its protection is raised") );
        }
    }
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
            @touches = touched-invariants($cand-doc, $diff).map({ %( id => .<id>, terms => .<terms>.List ) }) if $rc == 0;
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
    # Each change waits, or not, by the protection that governs the invariant it
    # touches: vibe waits for nobody; firm and solid wait for a yes.  A change
    # to the whole file (its purpose, its people, its mode) is governed by the
    # file's mode, except the mode itself, which always waits.  A failing
    # protecting test holds the commit only where the invariant is solid; under
    # firm or vibe it is reported.
    my sub level-of(%c --> Str) {
        return 'solid' if %c<kind> eq 'mode';
        %c<id>.defined ?? governing(%c<id>) !! ($base-mode // $cand-mode);
    }
    my sub waits(%c --> Bool) {
        # the mode itself, and the file's removal, wait whatever the mode: neither is a settling invariant
        return True if %c<kind> eq 'mode' | 'removed-file';
        if %c<kind> eq 'protection' {   # lowering waits at the level it had; raising in a settling file is free
            my $had = %rank{%c<before>} // %rank{$base-mode // 'solid'}; my $has = %rank{%c<after>} // %rank{$cand-mode};
            return $has < $had ?? $had >= 1 !! ($base-mode // 'solid') ne 'vibe';
        }
        %rank{level-of(%c)} >= 1;
    }
    my @asking  = (|@changes.grep({ .<kind> eq any(@AGREEMENT-KINDS) }), |@protections.grep({ .<kind> eq any(@PROTECTION-AGREEMENT-KINDS) }));
    my @waiting = @asking.grep({ waits($_) });
    my @settled = @asking.grep({ !waits($_) });
    my @failing = @checks.grep({ .<outcome> eq 'failed' });
    my @holding = @failing.grep({ so .<invariants>.grep({ governing($_) eq 'solid' }) });
    my @soft    = @failing.grep({ !so .<invariants>.grep({ governing($_) eq 'solid' }) });
    my @unrun   = @checks.grep({ .<outcome> eq any(<timeout unassessed>) && so .<invariants>.grep({ governing($_) ne 'vibe' }) });
    my @notes;
    my @next;
    my $blocked    = is-blocked(%p) || ?@holding;
    my $agree      = ?@waiting;
    my $unassessed = ?@unrun;
    %r<intent_mode> = $cand-mode;
    %r<protection>  = %( ($cand-doc.defined && $cand-doc.ok ?? $cand-doc.invariants.grep(*.id.defined).map({ .id => governing(.id) }) !! ()) );
    if ($base-mode // $cand-mode) eq 'vibe' {
        # nothing of the project's own waits or holds; what was noticed is said in one line
        %r<vibe> = %( changes => @settled.elems, failing => @soft.elems );
    }
    elsif @soft || @settled {
        %r<settling> = %( changes => @settled.elems, failing => @soft.elems );
        @notes.push: "{+@soft} protecting test{+@soft == 1 ?? '' !! 's'} failing ({@soft.map(*<file>).join(', ')}): reported, not held, while {@soft == 1 ?? 'the invariant is' !! 'the invariants are'} firm" if @soft;
    }
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
    # the proposal in plain words, for a person who is not reading JSON: a web page shows these lines
    %r<words>     = proposal-lines(%( changes => %r<changes>, protections => %r<protections> )).Array;
    %r<exit_code> = $enforce ?? %EXIT-CODE{$outcome} !! 0;

    given $outcome {
        when 'blocked' {
            @next.push: 'iz4 foundation restore' if @changes.grep({ .<kind> eq 'foundation' });
            @next.push: 'iz4 check' if @changes.grep({ .<kind> eq 'invalid' });
            @next.push: 'give the invariant a name the file has never used' if @changes.grep({ .<kind> eq 'reused-name' });
            @next.push: "keep the IZ4 in the canonical form" if @changes.grep({ .<kind> eq 'format-regressed' });
            @next.push: "iz4 approve   ({.<file>} fails: it asks which is right, the software or the invariant, and helps with either)" for @checks.grep({ .<outcome> eq 'failed' }).head(1);
        }
        when 'agreement-required' {
            # one command, and nothing to look up: approve finds the change, the key and where to send it
            @next.push: %snap<selection> eq 'staged'
                ?? 'iz4 approve'
                !! "iz4 approve --candidate={%snap<candidate_ref>}" ~ (%snap<base_ref> eq 'none' ?? ' --base=none' !! "");
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

#| What an enforcing hook runs.  When the gate needs agreement, or an
#| invariant no longer holds, and a person
#| is committing at a terminal, it asks them there and then and goes on
#| with the commit: no command to remember.  Anything else committing (a
#| script, an agent: no terminal on standard error) is refused as before.
constant GATE-HOOK-ENFORCE is export = q:to/END/.chomp;
    iz4 gate --staged --enforce --brief && exit 0
    rc=$?
    { [ "$rc" = 2 ] || [ "$rc" = 3 ]; } && [ -t 2 ] && [ -r /dev/tty ] || exit $rc
    iz4 approve </dev/tty || exit $rc
    exec iz4 gate --staged --enforce --brief
    END

#| The pre-commit hook: the gate on the staged tree.  Advisory unless
#| written with :enforce.
sub gate-hook-text(Bool :$enforce = False --> Str) is export {
    qq:to/END/;
    #!/bin/sh
    {GATE-HOOK-MARK} (written by 'iz4 gate install'; delete this file to remove it)
    command -v iz4 >/dev/null 2>&1 || exit 0
    {$enforce ?? GATE-HOOK-ENFORCE !! 'iz4 gate --staged --brief; exit 0'}
    END
}
