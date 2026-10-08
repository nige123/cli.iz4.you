unit module IZ4::Evidence;

#| Evidence that an invariant is kept.
#|
#| A checker cannot verify prose, but a test can pin the behaviour an
#| invariant describes, and a test that names its invariant can be found.
#| The convention is the invariant's own name: a test file that contains
#| its full identity (owner-adjusted.prices.honeywillow.com, in a comment,
#| a test name, anywhere) is evidence named for that invariant.  The name
#| is the whole link: no number, no position in the file, no quoted
#| words.  'iz4 check' reports which invariants have such a test, which
#| have only a scaffold, and which have nothing.
#|
#| 'iz4 test' writes the scaffold: one test file per invariant without
#| evidence, in the repository's own test language, carrying the
#| invariant's text and BECAUSE, and failing until a person replaces the
#| placeholder with an assertion that would fail if the invariant stopped
#| being true.  A scaffold is born red on purpose: a test that cannot fail
#| is not evidence, and a scaffold is not counted as evidence until its
#| placeholder is gone.  The name counts only as a whole: a longer name
#| that merely contains it (x.owner-adjusted.prices.honeywillow.com) is a
#| different invariant.
#|
#| A file still in the numbered format keeps the rule it was written
#| under, 'Invariant N' together with the invariant's opening words,
#| until 'iz4 migrate' names its invariants.
#|
#| None of this proves an invariant holds.  It makes visible which ones
#| have a test that says it does, and which have none.

use IZ4::Document;

#| The phrase a scaffold carries until it is written; its presence marks
#| a file as scaffolded rather than as evidence.
constant PLACEHOLDER is export = 'not yet tested: replace this with an assertion that would fail if the invariant stopped being true';

#| The line an agent-drafted test carries until a person has reviewed it;
#| its presence marks a file as drafted rather than as evidence.  Remove
#| the line once you have read the test, run it, and seen that it could
#| fail.
constant DRAFT-MARK is export = 'iz4 draft: an agent wrote this test; review it, run it, make sure it can fail, then delete this line';

#| Directories and file names that hold tests, by convention across
#| languages.  Only these are searched, so prose elsewhere that happens to
#| names an invariant is never mistaken for a test.
my @TEST-DIRS  = <t test tests spec specs __tests__ features>;
my regex test-file-name { [ '_test' | '.test' | '.spec' | '_spec' | 'Test' ] '.' \w+ $ | '.t' $ | '.rakutest' $ }
my @SKIP-DIRS  = <.git node_modules local vendor dist target .precomp build .venv venv>;

#| Would test-files count this repository-relative path as a test file?
#| The same rule, for a path that is not on disk yet (a Git tree listing).
sub is-test-path(Str $rel --> Bool) is export {
    my @parts = $rel.split('/');
    return False if @parts > 8;
    return False if so @parts.head(*-1).first({ $_ eq any(@SKIP-DIRS) });
    return False if @parts.tail.starts-with('.');
    so @parts.head(*-1).first({ $_ eq any(@TEST-DIRS) }) || so(@parts.tail ~~ &test-file-name);
}

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
                next if $e.basename.starts-with('.');       # editor swap files and the like
                @out.push: $e if $e.f && $e.s < 2_000_000;
            }
        }
    }
    walk($root, 0, False);
    @out;
}

#| Whether $text names invariant $id as a whole name: not as part of a
#| longer one on either side.  A full stop after it ends a sentence.
sub names-identity(Str $text, Str $id --> Bool) is export {
    my $from = 0;
    loop {
        my $at = $text.index($id, $from);
        return False without $at;
        my $before = $at > 0 ?? $text.substr($at - 1, 1) !! '';
        my $after  = $text.substr($at + $id.chars, 2);
        return True unless $before ~~ /^ <[A..Z a..z 0..9 . \-]> $/
            || $after ~~ /^ <[A..Z a..z 0..9 \-]> / || $after ~~ /^ '.' <[A..Z a..z 0..9]> /;
        $from = $at + 1;
    }
}

#| Which project invariants have evidence: returns a hash of
#| identity => 'named' (a reviewed test names it) | 'drafted' (an agent's
#| draft awaiting review) | 'scaffolded' (only the born-red scaffold) |
#| 'none', plus 'files' => identity => the files naming it.
sub evidence-for(IZ4::Document $doc, IO::Path $root --> Hash) is export {
    my @ids = $doc.invariants.map(*.id).grep(*.defined);
    my %state = @ids.map({ $_ => 'none' });
    my %opening = $doc.invariants.grep(*.id.defined).map({ .id => opening-words(.text) });
    my %files;
    my %rank = none => 0, scaffolded => 1, drafted => 2, named => 3;
    for test-files($root) -> $f {
        my $text = try $f.slurp;        # unreadable or not UTF-8: not evidence
        next without $text;
        my $here = $text.contains(PLACEHOLDER) ?? 'scaffolded' !! $text.contains(DRAFT-MARK) ?? 'drafted' !! 'named';
        my @linked;
        if $doc.legacy {
            my $flat = $text.lc.words.join(' ');
            @linked = $text.match(/ 'Invariant' \h+ (\d+) <!before \d> /, :g).map({ ~.[0] }).unique
                .grep({ (%state{$_}:exists) && $flat.contains(%opening{$_}) });
        }
        else {
            @linked = @ids.grep({ names-identity($text, $_) });
        }
        for @linked -> $id {
            %files{$id}.push: $f.relative($root);
            %state{$id} = $here if %rank{$here} > %rank{%state{$id}};
        }
    }
    %( :%state, :%files );
}

#| The first words of an invariant, normalised, that a test had to quote
#| under the numbered format.
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
        next unless %by-ext{$ext}:exists;
        my $lang = %by-ext{$ext};
        # .t is Perl's and Raku's alike: the file says which
        if $ext eq 't' {
            my $head = (try $f.slurp) // '';
            $lang = 'raku' if $head.contains('use v6') || $head.contains('use Test;') && !$head.contains('Test::More');
        }
        %seen{$lang}++;
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
constant LANGUAGES is export = <raku perl go python ruby rust typescript javascript sh>;

#| An identity as a word a programming language accepts in a name.
sub identity-slug(Str $id --> Str) is export { $id.subst(/ <-[a..z 0..9]> /, '_', :g) }

sub scaffold(Str $lang, $inv --> List) is export {
    die "no scaffold for language '$lang'; one of {LANGUAGES.join(', ')}" unless so $lang eq any(LANGUAGES);
    my $id   = $inv.id;
    my $slug = identity-slug($id);
    my $text = $inv.text;
    my $why  = $inv.because // '(no BECAUSE yet)';
    my $mark = $lang eq any(<go rust typescript javascript>) ?? '//' !! '#';
    # the invariant's name on a line of its own, then its words and its reason
    my $head = "$mark INVARIANT $id\n" ~ comment-lines($mark, $text) ~ "\n" ~ comment-lines($mark, "BECAUSE $why");
    given $lang {
        when 'raku' {
            "t/$id.rakutest", qq:to/END/;
            $head
            use Test;
            plan 1;
            flunk '$id: {PLACEHOLDER}';
            END
        }
        when 'perl' {
            "t/$id.t", qq:to/END/;
            $head
            use strict;
            use warnings;
            use Test::More tests => 1;
            fail('$id: {PLACEHOLDER}');
            END
        }
        when 'go' {
            "invariants/{$slug}_test.go", qq:to/END/;
            $head
            package invariants

            import "testing"

            func TestInvariant_{$slug}(t *testing.T) \{
            \tt.Fatal("$id: {PLACEHOLDER}")
            \}
            END
        }
        when 'python' {
            "tests/test_$slug.py", qq:to/END/;
            $head
            import pytest


            def test_{$slug}():
                pytest.fail("$id: {PLACEHOLDER}")
            END
        }
        when 'ruby' {
            "spec/{$slug}_spec.rb", qq:to/END/;
            $head
            RSpec.describe "$id" do
              it "{$text.subst('"', "'", :g)}" do
                raise "$id: {PLACEHOLDER}"
              end
            end
            END
        }
        when 'rust' {
            "tests/invariant_$slug.rs", qq:to/END/;
            $head
            #[test]
            fn invariant_{$slug}() \{
                panic!("$id: {PLACEHOLDER}");
            \}
            END
        }
        when 'typescript' | 'javascript' {
            my $ext = $lang eq 'typescript' ?? 'ts' !! 'js';
            "test/$id.test.$ext", qq:to/END/;
            $head
            test("$id: {$text.subst('"', "'", :g)}", () => \{
              throw new Error("$id: {PLACEHOLDER}");
            \});
            END
        }
        default {
            "t/$id.sh", qq:to/END/;
            #!/bin/sh
            $head
            echo "$id: {PLACEHOLDER}" >&2
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
#| Never overwrites.  Returns (path, identity) pairs written.
sub write-scaffolds(IZ4::Document $doc, IO::Path $root, Str :$lang = detect-language($root), :@only --> List) is export {
    my %e = evidence-for($doc, $root);
    my @done;
    for $doc.invariants -> $inv {
        next without $inv.id;
        next if @only && $inv.id ne any(@only);
        next if %e<state>{$inv.id} ne 'none';
        my ($rel, $text) = scaffold($lang, $inv);
        my $path = $root.add($rel);
        next if $path.e;
        $path.parent.mkdir;
        $path.spurt($text);
        $path.chmod(0o755) if $lang eq 'sh';
        @done.push: ($rel, $inv.id);
    }
    @done;
}

# ------------------------------------------------------------ agent drafts

#| The prompt that asks an agent for a real test.  It gets the invariant,
#| its reason, what the system is for, the language and file the test
#| must be, an existing test to match, and the file layout.  It must
#| refuse rather than fake: a test that cannot fail is worse than none.
sub draft-prompt($doc, $inv, Str :$lang!, Str :$path!, Str :$example = '', Str :$layout = '' --> Str) is export {
    my $because = $inv.because // '(the owner has not said why yet)';
    q:to/END/
    Write one test file for the software in this repository, pinning the
    invariant below.  The invariant is enduring intent from the project's
    IZ4 file; the test is evidence that the software keeps it.

    Rules:
    - The test must contain an assertion that would FAIL if the invariant
      stopped being true.  A test that passes whatever the code does is
      worse than no test: never write one.  Prefer the smallest real check
      over a broad fake one.
    - It must exercise this repository's actual code, in the style of the
      example test given, using the same framework and helpers.  Do not
      invent modules, functions, routes or fixtures that the layout does not
      show; if you must assume one, name the assumption in a comment.
    - Do not create, modify or delete any file: a person decides whether
      this test is written, after reading it.
    - Begin the file with a comment line "INVARIANT <its full name>",
      exactly as the name is given below, then comments quoting its text and
      "BECAUSE <reason>", in the comment style of the language.  The name is
      how the test is found: write it whole, never shortened.
    - If the invariant cannot be tested from what you can see - it depends on
      product intent, an external system, or code that is not here - reply
      with exactly one line: CANNOT: <one sentence saying why and what would
      be needed>.
    - Reply with the file content only: no fences, no commentary before or
      after.

    END
    ~ "Language and framework: $lang\nFile to write: $path\n\n"
    ~ "IS FOR WHAT? {$doc.for-what // ''}\nIS FOR WHO? {$doc.for-who // ''}\n\n"
    ~ "INVARIANT {$inv.id}\n{$inv.text}\n\nBECAUSE\n$because\n\n"
    ~ ($example ?? "An existing test in this repository, to match in style:\n=== example begin ===\n$example\n=== example end ===\n\n" !! '')
    ~ ($layout  ?? "File layout:\n$layout\n" !! '');
}

#| Read the agent's reply: a refusal ('CANNOT: ...'), or the file text
#| with any fences and chatter around it removed.  Returns a hash with
#| 'cannot' (the reason) or 'text'.
sub parse-draft(Str $reply --> Hash) is export {
    my $r = $reply.trim;
    with $r.lines.first(*.starts-with('CANNOT:')) { return %( cannot => .subst(/^ 'CANNOT:' \s*/, '').trim ) }
    my @lines = $r.lines;
    if @lines && @lines[0].starts-with('```') {
        @lines.shift;
        @lines.pop while @lines && !@lines[*-1].starts-with('```');
        @lines.pop if @lines && @lines[*-1].starts-with('```');
    }
    my $text = @lines.join("\n").trim;
    return %( cannot => 'the agent returned nothing usable' ) unless $text;
    return %( cannot => 'the agent left the placeholder in; nothing was asserted' ) if $text.contains(PLACEHOLDER);
    %( text => $text ~ "\n" );
}

#| A short example of this repository's existing tests, for the prompt.
sub example-test(IO::Path $root --> Str) is export {
    my @files = test-files($root).grep({ !.slurp.contains(PLACEHOLDER) && !.slurp.contains(DRAFT-MARK) });
    return '' unless @files;
    my $f = @files.sort({ .s }).first({ .s > 200 }) // @files[0];
    "--- {$f.relative($root)} ---\n" ~ $f.slurp.lines.head(60).join("\n");
}

#| The draft as it is written: the review line first, in the language's
#| comment style, so the file is counted as a draft until a person
#| removes it.
sub marked-draft(Str $lang, Str $text --> Str) is export {
    my $mark = $lang eq any(<go rust typescript javascript>) ?? '//' !! '#';
    my @lines = $text.lines;
    my $shebang = @lines && @lines[0].starts-with('#!') ?? @lines.shift ~ "\n" !! '';
    $shebang ~ "$mark {DRAFT-MARK}\n" ~ @lines.join("\n") ~ "\n";
}
