unit module IZ4::Evidence;

#| Evidence that an invariant is kept.
#|
#| A checker cannot verify prose, but a test can pin the behaviour an
#| invariant describes, and a test that names its invariant can be found.
#| The convention is one phrase: a test file that contains 'Invariant N'
#| (in a comment, a test name, anywhere) is evidence named for project
#| invariant N.  'iz4 check' reports which invariants have such a test,
#| which have only a scaffold, and which have nothing.
#|
#| 'iz4 test' writes the scaffold: one test file per invariant without
#| evidence, in the repository's own test language, carrying the
#| invariant's text and BECAUSE, and failing until a person replaces the
#| placeholder with an assertion that would fail if the invariant stopped
#| being true.  A scaffold is born red on purpose: a test that cannot fail
#| is not evidence, and a scaffold is not counted as evidence until its
#| placeholder is gone.  A file counts only when it also quotes the
#| invariant's own opening words, so a passing mention of 'Invariant 5' in
#| some other test is never taken as evidence.
#|
#| None of this proves an invariant holds.  It makes visible which ones
#| have a test that says it does, and which have none.

use IZ4::Document;

#| The phrase a scaffold carries until it is written; its presence marks
#| a file as scaffolded rather than as evidence.
constant PLACEHOLDER is export = 'not yet tested: replace this with an assertion that would fail if the invariant stopped being true';

#| Directories and file names that hold tests, by convention across
#| languages.  Only these are searched, so prose elsewhere that happens to
#| say 'Invariant 5' is never mistaken for a test.
my @TEST-DIRS  = <t test tests spec specs __tests__ features>;
my regex test-file-name { [ '_test' | '.test' | '.spec' | '_spec' | 'Test' ] '.' \w+ $ | '.t' $ | '.rakutest' $ }
my @SKIP-DIRS  = <.git node_modules local vendor dist target .precomp build .venv venv>;

#| Every test file under $root, to a sane depth.
sub test-files(IO::Path $root --> List) is export {
    my @out;
    my sub walk(IO::Path $dir, Int $depth, Bool $in-tests) {
        return if $depth > 6;
        for (try $dir.dir.sort) // () -> $e {
            next if so $e.basename eq any(@SKIP-DIRS);
            if $e.d {
                # so(): a junction argument would autothread the call, walking the tree once per name
                walk($e, $depth + 1, so($in-tests || $e.basename eq any(@TEST-DIRS)));
            }
            elsif $in-tests || $e.basename ~~ &test-file-name {
                @out.push: $e if $e.f && $e.s < 2_000_000;
            }
        }
    }
    walk($root, 0, False);
    @out;
}

#| Which project invariants have evidence: returns a hash of
#| number => 'named' (a test names it) | 'scaffolded' (only the born-red
#| scaffold) | 'none', plus 'files' => number => the files naming it.
sub evidence-for(IZ4::Document $doc, IO::Path $root --> Hash) is export {
    my %state = $doc.invariants.map(*.number).grep(*.defined).map({ $_ => 'none' });
    my %opening = $doc.invariants.grep(*.number.defined).map({ .number => opening-words(.text) });
    my %files;
    for test-files($root) -> $f {
        my $text = try $f.slurp // next;
        my $flat = $text.lc.words.join(' ');
        my $scaffold = $text.contains(PLACEHOLDER);
        for $text.match(/ 'Invariant' \h+ (\d+) <!before \d> /, :g).map({ +.[0] }).unique -> $n {
            next unless %state{$n}:exists;
            next unless $flat.contains(%opening{$n});     # names it AND quotes it
            %files{$n}.push: $f.relative($root);
            %state{$n} = 'named' if !$scaffold;
            %state{$n} = 'scaffolded' if $scaffold && %state{$n} eq 'none';
        }
    }
    %( :%state, :%files );
}

#| The first words of an invariant, normalised, that a test must quote.
sub opening-words(Str $text --> Str) is export {
    $text.lc.words.head(6).join(' ');
}

# --------------------------------------------------------------- scaffolds

#| The test language of a repository: from its existing tests first, then
#| from its project files.  Returns a name below, or 'sh' when nothing is
#| recognisable.
sub detect-language(IO::Path $root --> Str) is export {
    my %by-ext = rakutest => 'raku', t => 'perl', go => 'go', py => 'python',
        rb => 'ruby', rs => 'rust', ts => 'typescript', tsx => 'typescript', js => 'javascript', mjs => 'javascript';
    my %seen;
    for test-files($root) -> $f {
        my $ext = $f.extension;
        %seen{%by-ext{$ext}}++ if %by-ext{$ext}:exists;
    }
    return %seen.max(*.value).key if %seen;
    return 'raku'       if $root.add('META6.json').e;
    return 'perl'       if $root.add('cpanfile').e || $root.add('Makefile.PL').e || $root.add('dist.ini').e;
    return 'go'         if $root.add('go.mod').e;
    return 'rust'       if $root.add('Cargo.toml').e;
    return 'python'     if $root.add('pyproject.toml').e || $root.add('setup.py').e || $root.add('requirements.txt').e;
    return 'ruby'       if $root.add('Gemfile').e;
    if $root.add('package.json').e {
        return $root.add('tsconfig.json').e ?? 'typescript' !! 'javascript';
    }
    'sh';
}

#| Where a scaffold for one invariant goes, per language: (relative path,
#| file text).  Every scaffold names its invariant, carries the text and
#| the BECAUSE, and fails on PLACEHOLDER until written.
sub scaffold(Str $lang, $inv --> List) is export {
    my $n    = $inv.number;
    my $text = $inv.text;
    my $why  = $inv.because // '(no BECAUSE yet)';
    my $mark = $lang eq any(<go rust typescript javascript>) ?? '//' !! '#';
    # the invariant and its reason, wrapped, as comment lines
    my $head = comment-lines($mark, "Invariant $n: $text") ~ "\n" ~ comment-lines($mark, "BECAUSE $why");
    given $lang {
        when 'raku' {
            "t/invariant-$n.rakutest", qq:to/END/;
            $head
            use Test;
            plan 1;
            flunk 'Invariant $n: {PLACEHOLDER}';
            END
        }
        when 'perl' {
            "t/invariant-$n.t", qq:to/END/;
            $head
            use strict;
            use warnings;
            use Test::More tests => 1;
            fail('Invariant $n: {PLACEHOLDER}');
            END
        }
        when 'go' {
            "invariants/invariant_{$n}_test.go", qq:to/END/;
            $head
            package invariants

            import "testing"

            func TestInvariant{$n}(t *testing.T) \{
            \tt.Fatal("Invariant $n: {PLACEHOLDER}")
            \}
            END
        }
        when 'python' {
            "tests/test_invariant_$n.py", qq:to/END/;
            $head
            import pytest


            def test_invariant_{$n}():
                pytest.fail("Invariant $n: {PLACEHOLDER}")
            END
        }
        when 'ruby' {
            "spec/invariant_{$n}_spec.rb", qq:to/END/;
            $head
            RSpec.describe "Invariant $n" do
              it "{$text.subst('"', "'", :g)}" do
                raise "Invariant $n: {PLACEHOLDER}"
              end
            end
            END
        }
        when 'rust' {
            "tests/invariant_$n.rs", qq:to/END/;
            $head
            #[test]
            fn invariant_{$n}() \{
                panic!("Invariant $n: {PLACEHOLDER}");
            \}
            END
        }
        when 'typescript' | 'javascript' {
            my $ext = $lang eq 'typescript' ?? 'ts' !! 'js';
            "test/invariant-$n.test.$ext", qq:to/END/;
            $head
            test("Invariant $n: {$text.subst('"', "'", :g)}", () => \{
              throw new Error("Invariant $n: {PLACEHOLDER}");
            \});
            END
        }
        default {
            "t/invariant-$n.sh", qq:to/END/;
            #!/bin/sh
            $head
            echo "Invariant $n: {PLACEHOLDER}" >&2
            exit 1
            END
        }
    }
}

#| Text as comment lines wrapped at 78 columns.
sub comment-lines(Str $mark, Str $text --> Str) {
    my @lines; my $line = '';
    for $text.words -> $w {
        if $line eq '' { $line = $w }
        elsif $line.chars + 1 + $w.chars <= 76 - $mark.chars { $line ~= ' ' ~ $w }
        else { @lines.push($line); $line = $w }
    }
    @lines.push($line) if $line ne '';
    @lines.map({ "$mark $_" }).join("\n");
}

#| Write scaffolds for the invariants that have no evidence (or for @only).
#| Never overwrites.  Returns (path, number) pairs written.
sub write-scaffolds(IZ4::Document $doc, IO::Path $root, Str :$lang = detect-language($root), :@only --> List) is export {
    my %e = evidence-for($doc, $root);
    my @done;
    for $doc.invariants -> $inv {
        next without $inv.number;
        next if @only && $inv.number ne any(@only);
        next if %e<state>{$inv.number} ne 'none';
        my ($rel, $text) = scaffold($lang, $inv);
        my $path = $root.add($rel);
        next if $path.e;
        $path.parent.mkdir;
        $path.spurt($text);
        $path.chmod(0o755) if $lang eq 'sh';
        @done.push: ($rel, $inv.number);
    }
    @done;
}
