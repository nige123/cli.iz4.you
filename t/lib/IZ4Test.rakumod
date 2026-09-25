unit module IZ4Test;

#| A fresh temporary directory; removed at process exit.
sub temp-dir(--> IO::Path) is export {
    my $dir = $*TMPDIR.add("iz4-test-{$*PID}-{(^1_000_000).pick}");
    $dir.mkdir;
    END rm-rf($dir);
    $dir;
}

sub rm-rf(IO::Path $path) is export {
    return unless $path.e;
    if $path.d && !$path.l {
        rm-rf($_) for $path.dir;
        $path.rmdir;
    }
    else {
        $path.unlink;
    }
}

#| Run bin/iz4 in $cwd; returns (exit-code, stdout, stderr).
sub iz4(IO::Path $cwd, *@args) is export {
    my $root = $?FILE.IO.resolve.parent(3);
    # IZ4_TEST_BIN points the suite at a compiled iz4 (a Raku++ binary),
    # so CI tests the executable it ships, not the source it came from.
    my @cmd = %*ENV<IZ4_TEST_BIN>
        ?? (%*ENV<IZ4_TEST_BIN>,)
        !! ($*EXECUTABLE, '-I', $root.add('lib').Str, $root.add('bin/iz4').Str);
    my $proc = run |@cmd, |@args, :cwd($cwd.Str), :out, :err;
    my $out = $proc.out.slurp(:close);
    my $err = $proc.err.slurp(:close);
    $proc.exitcode, $out, $err;
}

#| Run bin/iz4 in $cwd with $input on standard input, as a person would
#| answer its questions (IZ4_INTERACTIVE=1 turns coaching on without a
#| terminal).  Returns (exit-code, stdout, stderr).
sub iz4-talk(IO::Path $cwd, Str $input, *@args) is export {
    my $root = $?FILE.IO.resolve.parent(3);
    my @cmd = %*ENV<IZ4_TEST_BIN>
        ?? (%*ENV<IZ4_TEST_BIN>,)
        !! ($*EXECUTABLE, '-I', $root.add('lib').Str, $root.add('bin/iz4').Str);
    my %env = %*ENV;
    %env<IZ4_INTERACTIVE> = '1';
    my $proc = run |@cmd, |@args, :cwd($cwd.Str), :in, :out, :err, :%env;
    $proc.in.print($input);
    my $ = $proc.in.close;         # sunk, a refusing exit would throw here; the code is read below
    my $out = $proc.out.slurp(:close);
    my $err = $proc.err.slurp(:close);
    $proc.exitcode, $out, $err;
}

#| A minimal current-format IZ4 in a fresh directory.
sub minimal-iz4(IO::Path :$dir = temp-dir(), Str :$extra = '' --> IO::Path) is export {
    my $path = $dir.add('IZ4');
    $path.spurt("IZ4\n\nIS FOR WHAT?\nHelping people find work they love to do.\n\n"
        ~ "IS FOR WHO?\nPeople looking for work.\n$extra");
    $path;
}

#| An independent system digest for cross-checking sha256-file, using
#| whichever tool this platform has.
sub sha256-hex(IO::Path $f --> Str) is export {
    for ('sha256sum',), ('shasum', '-a', '256'), ('openssl', 'dgst', '-sha256', '-r') -> @tool {
        my $hex = try {
            my $p = run |@tool.map(*.Str), $f.Str, :out, :err;
            my $o = $p.out.slurp(:close);
            $p.err.slurp(:close);
            $p.exitcode == 0 ?? $o.words.head.Str !! Str;
        };
        return $hex.lc if $hex.defined && $hex.chars == 64;
    }
    Str;
}

#| Can we run git here?  (Tests that need it skip otherwise.)
sub have-git(--> Bool) is export {
    my $p = try run 'git', '--version', :out, :err;
    $p.defined && $p.exitcode == 0;
}
