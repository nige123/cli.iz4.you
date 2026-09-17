unit module IZ4::Register;

use IZ4;
use IZ4::Document;
use IZ4::Git;

#| Client for the IZ4 register (iz4.you): the two commands
#| behind it (iz4 register, iz4 report) are the CLI's only network
#| opt-ins besides the agent behind suggest.  A report follows the register's
#| s2r-report contract and carries presence, digest, counts and check
#| outcomes - never the text of the IZ4.

constant REGISTER-START  is export = 'https://iz4.you/start';
constant REPORT-SCHEMA   is export = 's2r-report/1';

# ---------------------------------------------------------- connection

#| The file beside a IZ4 naming where it reports to.  Holds the reports
#| URL only - never the token, which stays outside the repository.
sub register-file(IO::Path $iz4 --> IO::Path) is export {
    $iz4.parent.add('.iz4-register');
}

sub register-url(IO::Path $iz4 --> Str) is export {
    for register-file($iz4), $iz4.parent.add('.spoz2-register') -> $f {
        return $f.slurp.trim if $f.f;    # legacy connection files still work
    }
    Str;
}

sub save-register-url(IO::Path $iz4, Str $url --> IO::Path) is export {
    my $f = register-file($iz4);
    $f.spurt($url.trim ~ "\n");
    $f;
}

#| Tokens live under the user's config directory, keyed by reports URL,
#| one "URL<TAB>token" per line, mode 0600.
sub token-store(--> IO::Path) is export {
    my $base = %*ENV<XDG_CONFIG_HOME> ?? %*ENV<XDG_CONFIG_HOME>.IO !! $*HOME.add('.config');
    $base.add('iz4').add('tokens');
}

sub save-token(Str $url, Str $token) is export {
    my $store = token-store();
    $store.parent.mkdir;
    $store.parent.chmod(0o700);
    my @lines = $store.f ?? $store.lines.grep({ .split("\t")[0] ne $url }) !! ();
    @lines.push: "$url\t$token";
    $store.spurt(@lines.join("\n") ~ "\n");
    $store.chmod(0o600);
}

#| The token for a reports URL: environment first (CI), then the store.
sub token-for(Str $url --> Str) is export {
    with %*ENV<IZ4_REGISTER_TOKEN> // %*ENV<SPOZ2_REGISTER_TOKEN> // %*ENV<S2R_TOKEN> { return .Str }
    for token-store(), token-store().parent.parent.add('spoz2').add('tokens') -> $store {
        next unless $store.f;    # the legacy spoz2 store is still honoured
        with $store.lines.first({ .split("\t")[0] eq $url }) { return .split("\t")[1].Str }
    }
    Str;
}

# --------------------------------------------------------------- badge

#| The public card and badge addresses for a connected IZ4, derived
#| offline from the stored reports URL - no account, no network.  The
#| badge renders the card's evidence honestly; embedding it claims
#| nothing the card cannot back.
sub badge-info(IO::Path $iz4 --> Hash) is export {
    my $url = register-url($iz4)
        // register-error("not connected to a register; run 'iz4 register' for the steps");
    $url ~~ m{^ (\w+ '://' <-[/]>+) '/api/' .* '/projects/' (<-[/]>+) '/reports' $}
        or register-error("cannot derive the card address from the stored reports URL ($url); "
            ~ "reconnect with 'iz4 register --url=...'");
    my $card = "$0/p/$1";
    %(
        card     => $card,
        badge    => "$card/badge.svg",
        markdown => "[![IZ4]($card/badge.svg)]($card)",
        html     => "<a href=\"$card\"><img src=\"$card/badge.svg\" alt=\"IZ4\"></a>",
    );
}

# -------------------------------------------------------------- GitHub

#| The workflow `iz4 register --github` writes.  On every push it
#| installs iz4 (its runtime cached between runs) and runs iz4 report,
#| so CI evidence carries a real syntax check.  It runs on GitHub's
#| machine, whatever system the maintainer develops on.
sub github-workflow(--> Str) is export {
    q:to/YAML/;
    name: iz4
    on: [push]
    jobs:
      report:
        runs-on: ubuntu-latest    # GitHub's machine, whatever system you develop on
        continue-on-error: true   # advisory: never blocks a release
        steps:
          - uses: actions/checkout@v4
          - uses: actions/cache@v4
            with:
              path: |
                ~/.rakubrew
                ~/.local/share/iz4
              key: iz4-runtime-${{ runner.os }}
          - run: curl -fsSL https://raw.githubusercontent.com/nige123/cli.iz4.you/main/install | sh
          - run: ~/.local/bin/iz4 report --release "$GITHUB_REF_NAME" --run-id "$GITHUB_RUN_ID"
            env:
              S2R_TOKEN: ${{ secrets.S2R_TOKEN }}
    YAML
}

sub repo-root(IO::Path $iz4 --> IO::Path) {
    my ($rc, $out, $) = git($iz4, 'rev-parse', '--show-toplevel');
    register-error('not in a Git repository; --github sets up the repository the IZ4 lives in')
        unless $rc == 0 && $out.trim;
    $out.trim.IO;
}

#| Write .github/workflows/iz4.yml at the repository root.  Never
#| overwrites a different file unless forced.  Returns 'written' or
#| 'unchanged'.
sub install-github-workflow(IO::Path $iz4, Bool :$force = False --> Str) is export {
    my $wf  = repo-root($iz4).add('.github').add('workflows').add('iz4.yml');
    my $txt = github-workflow();
    if $wf.f {
        return 'unchanged' if $wf.slurp eq $txt;
        register-error('.github/workflows/iz4.yml already exists and differs; remove it, or pass --force to replace it')
            unless $force;
    }
    $wf.parent.mkdir;
    $wf.spurt($txt);
    'written';
}

#| Store the token as the repository secret S2R_TOKEN with the GitHub CLI,
#| handed over on standard input so it never shows in a process listing.
#| Returns 'set', 'no-gh', or the GitHub CLI's error.
sub set-github-secret(IO::Path $iz4, Str $token --> Str) is export {
    my $root  = repo-root($iz4);
    my $probe = try run 'gh', '--version', :out, :err;
    return 'no-gh' without $probe;
    $probe.out.slurp(:close);
    $probe.err.slurp(:close);
    return 'no-gh' unless $probe.exitcode == 0;
    my $p = run 'gh', 'secret', 'set', 'S2R_TOKEN', :in, :out, :err, :cwd($root.Str);
    $p.in.print($token);
    try $p.in.close;
    $p.out.slurp(:close);
    my $err = $p.err.slurp(:close);
    $p.exitcode == 0 ?? 'set' !! ($err.trim || 'gh secret set failed');
}

# ------------------------------------------------------------ evidence

sub register-error(Str $message) { X::IZ4.new(:$message).throw }

#| Evidence about one IZ4, mirroring the register's s2r-report contract.
sub collect-report(IO::Path $iz4, Str :$release, Str :$run-id --> Hash) is export {
    my ($rc, $out, $) = git($iz4, 'rev-parse', 'HEAD');
    my $revision = $out.trim;
    register-error('not in a Git repository; evidence must bind to an exact revision')
        unless $rc == 0 && $revision ~~ /^ <[0..9 a..f]> ** 40 $/;

    my %declaration = present => $iz4.f;
    my %checks;
    if $iz4.f {
        %declaration<digest> = sha256-file($iz4);
        my $doc = IZ4::Document.load($iz4);
        # the grammar label names the dialect; the count is the project's
        # own invariants in the file (the inherited 0-4 are never counted)
        %declaration<grammar_version> = $doc.is-legacy ?? 'IZ4 legacy' !! 'IZ4';
        %declaration<invariant_count> = $doc.invariants.elems;
        %checks<syntax> = %( outcome => $doc.ok ?? 'passed' !! 'failed' );
    }

    my %report =
        schema_version => REPORT-SCHEMA,
        report_id      => $revision.substr(0, 12) ~ '-' ~ time,
        revision       => $revision,
        declaration    => %declaration,
        checks         => %checks,
        tool           => "iz4/{VERSION}",
        observed_at    => DateTime.now.utc.truncated-to('second').Str;
    %report<release_label> = $_ with $release;
    %report<run_id>        = $_ with $run-id;
    %report;
}

# ---------------------------------------------------------------- JSON

#| Canonical JSON (sorted keys), enough for the report payload.
sub json-encode(\v --> Str) is export {
    return 'null' without v;
    given v {
        when Bool        { v ?? 'true' !! 'false' }
        when Str         { json-str(v) }
        when Numeric     { v.Str }
        when Associative { '{' ~ v.pairs.sort(*.key).map({ json-str(.key.Str) ~ ':' ~ json-encode(.value) }).join(',') ~ '}' }
        when Positional  { '[' ~ v.map({ json-encode($_) }).join(',') ~ ']' }
        default          { json-str(v.Str) }
    }
}

sub json-str(Str $s --> Str) {
    my $out = $s.subst(/ <[\\"]> /, { '\\' ~ $_ }, :g);
    $out .= subst(/ <:Cc> /, { sprintf '\u%04x', .Str.ord }, :g);
    '"' ~ $out ~ '"';
}

# -------------------------------------------------------------- submit

#| POST the report with curl (external, like Git).  Returns (status, body);
#| status 0 means curl was missing or the register was unreachable.  The
#| token travels in a 0600 header file, not on the command line.
sub submit-report(Str $url, Str $token, Str $body --> List) is export {
    my $dir = $*TMPDIR.add("iz4-{$*PID}-{(^1_000_000).pick}");
    $dir.mkdir;
    $dir.chmod(0o700);
    my $hdr = $dir.add('auth');
    $hdr.spurt("Authorization: Bearer $token\n");
    $hdr.chmod(0o600);
    LEAVE { .unlink for (try $dir.dir) // (); try $dir.rmdir }

    my $p = try run 'curl', '-sS', '--max-time', '15',
        '-o', '-', '-w', '\n%{http_code}',
        '-X', 'POST',
        '-H', 'Content-Type: application/json',
        '-H', '@' ~ $hdr.Str,
        '--data-binary', '@-', $url, :in, :out, :err;
    return (0, 'curl is required to talk to the register and was not found') without $p;
    $p.in.print($body);
    try $p.in.close;
    my $out = $p.out.slurp(:close);
    my $err = $p.err.slurp(:close);
    return (0, $err.trim || 'network request failed') if $p.exitcode != 0;

    my @lines = $out.lines;
    my $code  = (try @lines.tail.Int) // 0;
    ($code, @lines.head(* - 1).join("\n"));
}
