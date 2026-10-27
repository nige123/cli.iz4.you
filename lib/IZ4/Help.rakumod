unit module IZ4::Help;

#| Help a person can hold in their head.
#|
#| 'iz4 help' shows the handful of commands for everyday work and the
#| few for when intent changes, and stops.  Everything else is one step
#| away: 'iz4 help more' lists the rest in small groups, and 'iz4 help
#| <command>' says what one command is for, how to call it, and gives
#| one example.  No screen here is long, on purpose: a person reading
#| help is in the middle of something else.
#|
#| An action is a word, never a flag: 'iz4 foundation restore', 'iz4
#| test list'.  Flags only adjust how a command does its one thing.

#| A topic: the words that name it, the group it is listed under, one
#| line saying what it is for, how to call it, a few lines more, and one
#| example.
class Topic is export {
    has Str $.name    is required;
    has Str $.group   is required;
    has Str $.summary is required;
    has @.usage;
    has Str $.more = '';
    has Str $.example = '';
}

sub t(Str $name, Str $group, Str $summary, @usage, Str $more = '', Str $example = '') {
    Topic.new(:$name, :$group, :$summary, :@usage, :$more, :$example);
}

constant EVERY-DAY is export = 'Every day';
constant CHANGE    is export = 'When intent changes';

#| Every command, in the order it is listed.
sub topics(--> List) is export {
    (
    t('init', EVERY-DAY, 'start an IZ4 here',
      ['iz4 init'],
      'Drafts what this is for and who it is for with the agent you already use, and you keep each answer or type your own. It then sets up the commit hook and your agents, and offers to find a first promise. A script gives both answers, and the domain it names promises under: --for-what=... --for-who=... --namespace=your.domain',
      'iz4 init'),
    t('add', EVERY-DAY, 'find a promise, one question at a time',
      ['iz4 add', 'iz4 add promise ALWAYS --when=... --protects=... --name=NAME [--established]', 'iz4 add for-what TEXT', 'iz4 add for-who TEXT'],
      'Alone, it coaches you to one promise in three questions: when it applies (WHEN), what must remain true (ALWAYS), whose what it protects (PROTECTS), then its name. A new invariant is exploring unless --established. With the words, it adds at once.',
      "iz4 add promise 'Charged once.' --when='an order is paid' --protects=\"a buyer's money\" --name=charged-once"),
    t('status', EVERY-DAY, 'where things stand: the foundation, each invariant, this change',
      ['iz4 status', 'iz4 status --recheck', 'iz4 status --no-checks', 'iz4 status --json', 'iz4 status --brief'],
      'One screen: the foundation, each invariant with its mark and the share held, what is staged, your agents, the next command. Tests run when the tree changed; --recheck always, --no-checks never. Never claims safety.',
      'iz4 status'),
    t('check', EVERY-DAY, 'what is true of the file, and what to do next',
      ['iz4 check', 'iz4 check --strict'],
      'Ticks what is true, marks what is not, and lists the next steps in order. It fails only on errors; --strict fails on anything marked. It never says the software keeps its invariants: it cannot know.',
      'iz4 check'),
    t('show', EVERY-DAY, 'read the IZ4, or one part of it',
      ['iz4 show', 'iz4 show for-what | for-who | invariants', 'iz4 show invariant NAME'],
      'The first part of a name will do where only one invariant begins with it. The foundation\'s five are found by name the same way. The mark before a name: a closed green diamond when its test passed at the last iz4 status, an open one for a promise nothing yet shows, a red cross when the test fails, ? when it could not be checked.',
      'iz4 show invariant charged-once'),
    t('test', 'Shaping an invariant', 'a test for each invariant that has none',
      ['iz4 test', 'iz4 test NAME', 'iz4 test list'],
      'Writes a test that fails until you make it real, in your own test language. With an agent on a terminal it drafts a real one for you to approve. list shows the evidence each invariant has.',
      'iz4 test list'),

    t('gate', CHANGE, 'does this change alter a commitment?',
      ['iz4 gate --staged', 'iz4 gate --candidate=REV --base=REV', 'iz4 gate install'],
      'Compares two trees: the IZ4 and the tests that name invariants. It says pass, agreement-required, blocked or unassessed. --enforce makes that the exit code. install adds a pre-commit hook.',
      'iz4 gate --staged'),
    t('approve', CHANGE, 'settle a change to what the software promises: a person, never a script',
      ['iz4 approve'],
      'One thing at a time. It shows each change and asks if it is what you mean. Where an invariant no longer holds, it asks which is right, the software or the invariant, and helps with either. It finds your key, signs and sends the approval on. Nothing to look up.',
      'iz4 approve'),
    t('establish', CHANGE, 'the promise is agreed: changes to it wait for your yes, failing tests hold',
      ['iz4 establish', 'iz4 establish NAME'],
      'Writes on its card: CHANGES REQUIRE signed human approval for the exact change; CHECKED WITH linked tests; failures block commit. Alone, it says where every invariant stands. A new invariant starts exploring.',
      'iz4 establish charged-once'),
    t('explore', CHANGE, 'let the invariant move again: its promise may change while it settles',
      ['iz4 explore NAME'],
      'Writes on its card: CHANGES REQUIRE no approval; current promise still applies; CHECKED WITH linked tests; failures warn, never block. The promise as written still binds. Lowering is itself a change the gate asks about at commit time.',
      'iz4 explore charged-once'),
    t('withdraw', 'Shaping an invariant', 'take an invariant out, with its tests',
      ['iz4 withdraw NAME'],
      'Shows the invariant and the tests that exist only for it, asks once, and removes them. Git keeps all of it. The name is retired for good. --keep-tests leaves the tests.',
      'iz4 withdraw charged-once'),

    t('protects', 'Shaping an invariant', 'say whose what a promise protects: its PROTECTS',
      ['iz4 protects NAME WHAT'],
      'What must not be defeated, as whose what: a noun phrase, never a sentence. --replace changes one already given.',
      'iz4 protects charged-once "a customer\'s money"'),
    t('when', 'Shaping an invariant', 'say when a promise applies: its WHEN',
      ['iz4 when NAME SITUATION'],
      'The situation the promise applies in, not who benefits. ALWAYS binds throughout it, and a boundary only counts if ALWAYS says it. Say it in the words you would use out loud.',
      "iz4 when private-stays-private 'a private profile can be seen by anyone but its owner'"),
    t('suggest', 'Shaping an invariant', 'ask an agent for a few candidates',
      ['iz4 suggest'],
      'It reads the repository and proposes a few. You decide; nothing is added without your yes.',
      'iz4 suggest'),
    t('review', 'Shaping an invariant', 'read a change against the invariants',
      ['iz4 review', 'iz4 review --staged', 'iz4 review install'],
      'Says which invariants a change touches, then asks your agent what it makes of it. --offline skips the agent. install adds an advisory pre-push hook.',
      'iz4 review --staged'),

    t('invariants', 'Reading', 'the foundation and your own, together',
      ['iz4 invariants'], 'What a person or an agent should read before a consequential change.', 'iz4 invariants'),
    t('foundation', 'Reading', 'the foundation every IZ4 carries',
      ['iz4 foundation', 'iz4 foundation restore'],
      'The same words in every IZ4, beginning with Invariant Zero. restore writes it back into a file where it is missing, altered or out of date.',
      'iz4 foundation restore'),
    t('log', 'Reading', 'the history of the IZ4', ['iz4 log'], 'Git history of the file.', 'iz4 log'),
    t('diff', 'Reading', 'what changed in the IZ4', ['iz4 diff', 'iz4 diff REV', 'iz4 diff REV REV'], 'Git diff of the file.', 'iz4 diff HEAD~1'),

    t('migrate', 'Moving forward', 'bring an IZ4 written by an earlier iz4 to promise cards',
      ['iz4 migrate', 'iz4 migrate preview', 'iz4 migrate --where=NAME=SITUATION|...'],
      'Your words are never touched: each of your own becomes a PROMISE card, the foundation FOUNDATION cards. preview shows what would change. A file still in the earliest named form has no WHEN yet: you are asked for each; in a script, --where gives them.',
      'iz4 migrate preview'),

    t('agent', 'Working with agents', 'what an agent must read before it works here',
      ['iz4 agent', 'iz4 agent --json'], 'The protocol and the effective invariants, in one packet.', 'iz4 agent'),
    t('agent install', 'Working with agents', 'tell agents in this repository about the IZ4',
      ['iz4 agent install', 'iz4 agent install claude skill', 'iz4 agent install hooks'],
      'Adds a managed section to AGENTS.md; claude adds CLAUDE.md, skill the portable skill. hooks asks the driver (321) to wire the harness; --strict asks for everything it can enforce.',
      'iz4 agent install claude skill'),
    t('agent status', 'Working with agents', 'what is wired, and what each harness enforces',
      ['iz4 agent status'], 'Says what is in place and what is not, and never that an agent read or followed anything.', 'iz4 agent status'),

    t('register', 'The register', 'connect this IZ4 to iz4.you',
      ['iz4 register'], 'Sign up at iz4.you first. Once connected, it records a checkpoint of the committed IZ4.', 'iz4 register'),
    t('report', 'The register', 'send evidence to the register, never the text',
      ['iz4 report', 'iz4 report preview'], 'preview shows what would be sent and sends nothing.', 'iz4 report preview'),
    t('badge', 'The register', 'the card link and badge for your README', ['iz4 badge'], '', 'iz4 badge'),

    t('version', 'The tool', 'which iz4 this is', ['iz4 version', 'iz4 version --brief'], '--brief prints the version alone, for a script.', 'iz4 version'),
    t('completion', 'The tool', 'tab completion for your shell',
      ['iz4 completion bash', 'iz4 completion zsh', 'iz4 completion fish'],
      'Prints a completion script made from this help, so it always matches the commands. Bash: add  source <(iz4 completion bash)  to ~/.bashrc. Zsh: save it as _iz4 in a directory on your fpath. Fish: save it as ~/.config/fish/completions/iz4.fish.',
      'source <(iz4 completion bash)'),
    t('update', 'The tool', 'bring iz4 up to date',
      ['iz4 update', 'iz4 update check'], 'check only says whether a newer one exists.', 'iz4 update check'),
    t('help', 'The tool', 'this help',
      ['iz4 help', 'iz4 help COMMAND', 'iz4 help more', 'iz4 help machine'], '', 'iz4 help add'),

    t('discover', 'For tools', 'does an IZ4 govern this directory?', ['iz4 discover --json'], '', 'iz4 discover --json'),
    t('draft', 'For tools', 'the three questions for writing a promise, and a check of an answer',
      ['iz4 draft questions', 'iz4 draft check --when=SITUATION --always=STATE --protects=WHOSE-WHAT'],
      'JSON for a page that is not a terminal. It asks questions and never refuses: a person decides. With --name and a file it also says whether the name can be used and what the digest would be.',
      'iz4 draft questions'),
    t('context', 'For tools', 'what to tell an agent before it works', ['iz4 context --json'], '', 'iz4 context --json'),
    t('check action', 'For tools', 'does one action need a person?',
      ['iz4 check action --json'], 'The action is JSON on standard input: operation, target, parameters.', "echo '\{\"operation\":\"write\",\"target\":\"IZ4\"\}' | iz4 check action --json"),
    t('check change', 'For tools', 'does this change alter a commitment?',
      ['iz4 check change --worktree --json', 'iz4 check change --staged --json'], 'The gate, in the vocabulary a tool reads. --worktree looks at uncommitted work and touches no index.', 'iz4 check change --worktree --json'),
    t('verify', 'For tools', 'what can be established about finished work',
      ['iz4 verify --worktree --json', 'iz4 verify --worktree --summary=FILE --json', 'iz4 verify --worktree --base=TREE --summary=FILE --json'], 'Structure, change, and, given the agent\'s last words, its report. Results are pass, warn, block or needs_human. --base=TREE measures the change from the tree the turn began with (evidence.gate.candidate of the last run), not from HEAD, so files already dirty are not the turn\'s. docs/drivers.md', 'iz4 verify --worktree --json'),
    t('hook', 'For tools', 'what wiring made by an earlier iz4 still calls',
      ['iz4 hook EVENT'],
      'EVENT is session-start, pre-edit or stop. Reads the harness event as JSON, prints text for the model, and refuses with exit 2 and a reason. Kept so earlier wiring keeps working; the driver (321) wires harnesses now.',
      'iz4 hook EVENT < event.json'),
    )
}

#| A shell completion script, made from the help topics so it always
#| matches the commands: the first word, the words that follow it, and the
#| flags its help shows.  It only prints; nothing is installed or run.
sub completion-script(Str $shell --> Str) is export {
    my @first = topics().map(*.name.words[0]).unique;
    my %summary = topics().grep({ .name.words == 1 }).map({ .name => .summary });
    my %after;
    for topics() -> $t {
        my $w = $t.name.words[0];
        %after{$w}.push: $t.name.words[1] if $t.name.words > 1;
        %after{$w}.append: $t.usage.join(' ').comb(/ '--' <[a..z]> <[a..z\-]>* /);
    }
    %after{$_} = (%after{$_} // ()).unique.List for @first;
    my sub zq(Str $s) { $s.subst(':', '\:', :g).subst("'", "'\\''", :g) }
    my sub fq(Str $s) { $s.subst("'", "\\'", :g) }
    given $shell {
        when 'bash' {
            my @l = '# iz4 completion for bash: source <(iz4 completion bash)', '_iz4() {',
                    '    local cur=${COMP_WORDS[COMP_CWORD]}',
                    "    if [ \$COMP_CWORD -eq 1 ]; then COMPREPLY=(\$(compgen -W \"{@first.join(' ')}\" -- \"\$cur\")); return; fi",
                    '    case "${COMP_WORDS[1]}" in';
            @l.push: "        $_) COMPREPLY=(\$(compgen -W \"{%after{$_}.join(' ')}\" -- \"\$cur\"));;" for @first.grep({ %after{$_} });
            @l.append: '    esac', '}', 'complete -F _iz4 iz4';
            @l.join("\n") ~ "\n";
        }
        when 'zsh' {
            my @l = '#compdef iz4', '# iz4 completion for zsh: save as _iz4 on your fpath', '_iz4() {',
                    '    local -a commands', '    commands=(';
            @l.push: "        '{zq($_)}:{zq(%summary{$_} // '')}'" for @first;
            @l.append: '    )', '    if (( CURRENT == 2 )); then _describe -t commands "iz4 command" commands; return; fi',
                       '    case $words[2] in';
            @l.push: "        $_) compadd -- {%after{$_}.join(' ')};;" for @first.grep({ %after{$_} });
            @l.append: '    esac', '}', 'compdef _iz4 iz4';
            @l.join("\n") ~ "\n";
        }
        when 'fish' {
            my @l = '# iz4 completion for fish: save as ~/.config/fish/completions/iz4.fish', 'complete -c iz4 -f';
            @l.push: "complete -c iz4 -n __fish_use_subcommand -a $_ -d '{fq(%summary{$_} // '')}'" for @first;
            for @first.grep({ %after{$_} }) -> $w {
                for %after{$w}.list -> $a {
                    @l.push: $a.starts-with('--')
                        ?? "complete -c iz4 -n '__fish_seen_subcommand_from $w' -l {$a.substr(2)}"
                        !! "complete -c iz4 -n '__fish_seen_subcommand_from $w' -a $a";
                }
            }
            @l.join("\n") ~ "\n";
        }
    }
}

sub topic(Str $name --> Topic) is export { topics().first({ .name eq $name }) // Topic }

#| The first screen: what iz4 is, the commands for everyday work, the
#| few for when intent changes, and where the rest is.  Nothing more.
#| Windows Terminal is UTF-8 without saying so in LANG.
my sub utf8-terminal(--> Bool) { so ((%*ENV<LC_ALL> // %*ENV<LC_CTYPE> // %*ENV<LANG> // '') ~~ /:i 'utf' '-'? '8'/) || (%*ENV<WT_SESSION> // '') ne '' }

#| The mark in text, one line: the icon, then the name and what it is for.
#| A line of air above and below, so the first screen opens calmly.
sub text-logo(--> List) is export {
    ("{diamond()} iz4: what your software is for, who it is for, and what must stay true.",);
}

sub help-index(--> Str) is export {
    my @l = '', |text-logo(), '';
    for EVERY-DAY, CHANGE -> $g {
        @l.push: $g;
        @l.push: sprintf('  iz4 %-10s %s', .name, .summary) for topics().grep({ .group eq $g });
        @l.push: '';
    }
    @l.push: 'iz4 help COMMAND    more on one command, with an example';
    @l.push: 'iz4 help more       the rest: reading, shaping, agents, the register';
    @l.push: '';
    @l.join("\n") ~ "\n";
}

#| Everything not on the first screen, in small groups.  The commands a
#| tool calls are left to 'iz4 help machine'.
sub help-more(--> Str) is export {
    my @l = '', "{diamond()} iz4 help more: reading, shaping, agents, the register", '';
    for topics().map(*.group).unique.grep({ $_ ne EVERY-DAY && $_ ne CHANGE && $_ ne 'For tools' }) -> $g {
        @l.push: $g;
        @l.push: sprintf('  iz4 %-14s %s', .name, .summary) for topics().grep({ .group eq $g });
        @l.push: '';
    }
    @l.push: 'iz4 help COMMAND    more on one command, with an example';
    @l.push: 'iz4 help machine    the commands a tool calls';
    @l.push: '';
    @l.push: 'Highlights appear only on a terminal: NO_COLOR or IZ4_COLOR=0 turns them off, IZ4_COLOR=1 keeps them; --json is for tools.';
    @l.push: '';
    @l.join("\n") ~ "\n";
}

sub help-machine(--> Str) is export {
    my @l = '', "{diamond()} iz4 help machine: what an environment driver, a hook or a CI job calls", '';
    @l.push: sprintf('  iz4 %-14s %s', .name, .summary) for topics().grep({ .group eq 'For tools' });
    @l.push: '';
    @l.push: 'Each answers with a document (--json) and an exit code: 0 pass or warn,';
    @l.push: '2 a person must decide, 3 blocked, 1 the check could not run.';
    @l.push: 'docs/drivers.md has the contract.';
    @l.push: '';
    @l.push: 'Pipeline form: --brief, or IZ4_BRIEF=1. One tab-separated record a line,';
    @l.push: 'no title or colour; a failure is one stderr line and the exit code.';
    @l.push: '  iz4 status --brief     foundation STATE / invariant NAME MARK EVIDENCE / next COMMAND';
    @l.push: '  iz4 check --brief      pass|fail|uncertain WHAT DETAIL / next STEP';
    @l.push: '  iz4 invariants --brief foundation NAME / promise NAME STANDING';
    @l.push: '  iz4 show invariant NAME --brief   NAME WHEN ALWAYS PROTECTS';
    @l.push: '  iz4 log --brief        DATE REVISION SUBJECT';
    @l.push: '  iz4 version --brief    the version alone';
    @l.push: '  iz4 gate --brief       one line when the change passes';
    @l.push: 'A usage error asked for with --json answers with schema iz4-error/1.';
    @l.join("\n") ~ "\n";
}

sub wrap-at(Str $text, Int $width --> List) {
    my @lines; my $line = '';
    for $text.words -> $w {
        if $line eq '' { $line = $w }
        elsif $line.chars + 1 + $w.chars <= $width { $line ~= ' ' ~ $w }
        else { @lines.push($line); $line = $w }
    }
    @lines.push($line) if $line ne '';
    @lines.List;
}

#| One command: what it is for, how to call it, a little more, one example.
sub help-topic(Topic $t --> Str) is export {
    my @l = '', "{diamond()} iz4 {$t.name}: {$t.summary}", '';
    @l.push: "  $_" for $t.usage;
    if $t.more ne '' { @l.push: ''; @l.append: wrap-at($t.more, 76) }
    if $t.example ne '' { @l.push: '', 'For example:', "  {$t.example}" }
    @l.push: '';
    @l.join("\n") ~ "\n";
}

#| Help for what was asked: nothing (the first screen), 'more', 'machine',
#| a command, or a word that begins some commands.  Returns the text and
#| whether the request was understood.
# How many letters apart two words are: a slip of the fingers is one or two.
sub distance(Str $a, Str $b --> Int) {
    my @prev = 0 .. $b.chars;
    for 1 .. $a.chars -> $i {
        my @row = $i;
        for 1 .. $b.chars -> $j {
            my $cost = $a.substr($i - 1, 1) eq $b.substr($j - 1, 1) ?? 0 !! 1;
            @row.push: min(@prev[$j] + 1, @row[$j - 1] + 1, @prev[$j - 1] + $cost);
        }
        @prev = @row;
    }
    @prev[*-1];
}

# ------------------------------------------------------------ pretty

#| Whether to dress output for a person: only on a terminal, never into a
#| pipe, a file or a test, so what a tool reads is byte for byte what it
#| always was.  NO_COLOR and TERM=dumb turn it off; IZ4_COLOR=1 or 0 says
#| outright.
sub pretty-on(--> Bool) is export {
    return %*ENV<IZ4_COLOR> eq '1' if (%*ENV<IZ4_COLOR> // '') eq any('0', '1');
    return False if (%*ENV<NO_COLOR> // '') ne '' || (%*ENV<TERM> // '') eq 'dumb';
    so $*OUT.t;
}


#| The brand's green, as this terminal can show it; ink stays the terminal's own.
my sub green(--> Str) { (%*ENV<COLORTERM> // '') eq 'truecolor' | '24bit' ?? "\e[38;2;31;145;86m" !! "\e[38;5;29m" }
my constant BOLD  = "\e[1m";
my constant DIM   = "\e[2m";
my constant RED   = "\e[31m";
my constant AMBER = "\e[33m";
my constant OFF   = "\e[0m";

#| The icon that marks an invariant: a diamond holding a diamond, the
#| brand's mark in one character.
sub diamond(--> Str) is export { utf8-terminal() ?? '◈' !! '*' }

#| Before a name, one of four marks says what is known of the invariant.
#| Each is a different shape, so it reads without colour, and each has a
#| plain twin for a terminal that cannot draw it:
#|   held      ◆ (*)  a test names it and passed; the foundation, word for word
#|   promised  ◇ (o)  in the IZ4 and settled; nothing yet shows it holds
#|   broken    ✕ (x)  a test names it and fails
#|   unknown   ? (?)  it could not be checked: no run, no runner, a timeout
#| The command sets the map from the evidence before it prints.  A name
#| the map does not know keeps the icon: this command assessed nothing.
my %SOLID;
sub mark-solid(%solid) is export { %SOLID = %solid }
my constant %GLYPH = held => ('◆', '*'), promised => ('◇', 'o'), broken => ('✕', 'x'), unknown => ('?', '?');
#| The state behind a name: held, promised, broken, unknown, or '' when the
#| map does not know it.  True and False still mean held and promised.
sub mark-state(Str $name --> Str) is export {
    return '' unless %SOLID && (%SOLID{$name}:exists);
    my $v = %SOLID{$name};
    $v ~~ Bool ?? ($v ?? 'held' !! 'promised') !! ~$v;
}
sub mark-for(Str $name --> Str) is export {
    my $s = mark-state($name);
    return diamond() unless $s;
    %GLYPH{$s}[utf8-terminal() ?? 0 !! 1];
}
#| The mark with its colour, for a line a command builds itself: green when
#| held, red when broken, plain otherwise; plain throughout when colour is off.
sub mark-shown(Str $name, Bool :$on = pretty-on() --> Str) is export {
    my $m = mark-for($name);
    return $m unless $on;
    given mark-state($name) { when 'held' | '' { green() ~ $m ~ OFF }; when 'broken' { RED ~ $m ~ OFF }; default { $m } }
}
#| The marks and what each means, one line, as this terminal draws them.
sub marks-legend(--> Str) is export {
    my $i = utf8-terminal() ?? 0 !! 1;
    "{%GLYPH<held>[$i]} held  {%GLYPH<promised>[$i]} promised, nothing shows it yet  {%GLYPH<broken>[$i]} broken  {%GLYPH<unknown>[$i]} not checked";
}

#| Text as a person sees it on a terminal: a promise's name under a
#| green diamond, the field labels and the two questions in bold,
#| comments dimmed, ticks green and crosses red.  Nothing is added or
#| removed but colour, and the diamond that stands in for PROMISE or
#| FOUNDATION (and, in the earlier forms and the gate's proposal lines,
#| for INVARIANT or the heading's colon).  With :!on the text comes back
#| untouched.  Within a line: a promise's name (a dotted name with a
#| letter first and two dots or more, so a version or a file is not one)
#| and the keywords of every form, in bold.
my sub emphasise(Str $s --> Str) {
    $s.subst(/ <!after <[\w / : . \-]>> (<[a..z]> <[a..z 0..9 \-]>* ['.' <[a..z 0..9 \-]>+] ** 2..*) <!before <[\w /]>> /, { "{BOLD}{$0}{OFF}" }, :g)
      .subst(/ <!after \w> ('IS FOR WHAT' '?'? | 'IS FOR WHO' '?'? | 'INVARIANT' | 'PROMISE' | 'FOUNDATION' | 'WHEN' | 'WHERE' | 'ALWAYS' | 'PROTECTS' | 'CHANGES REQUIRE' | 'CHECKED WITH' | 'BECAUSE') <!before \w> /, { "{BOLD}{$0}{OFF}" }, :g)
}

sub pretty(Str $text, Bool :$on = pretty-on() --> Str) is export {
    return $text unless $on;
    my $g = green();
    my $d = diamond();
    $text.lines(:!chomp).map(-> $line {
        my $nl = $line.ends-with("\n") ?? "\n" !! '';
        my $l = $line.chomp;
        # the lines that open a section, before a heading could be taken for one
        if $l ~~ / ^ ('outcome' | 'next' | 'gate' | 'commitments and protections' | 'checks' | 'touches' | 'approval' | 'checked' | 'All held') ':' (.*) $ / { $l = "{BOLD}{$0}:{OFF}{emphasise(~$1)}" }
        # the earlier forms' headings: a name with a colon (clauses), INVARIANT name (named); and the gate's proposal
        # lines, which lead with PROMISE or INVARIANT and go on in the same line
        elsif $l ~~ / ^ (<[a..z 0..9]> <[\w.\-]>*) ':' (\h*) $ / { $l = "{mark-shown(~$0, :on)} {BOLD}{$0}{OFF}{$1}" }
        elsif $l ~~ / ^ (\h*) ('INVARIANT' | 'PROMISE') ' ' (\S+) (.*) $ / { $l = "{$0}{mark-shown(~$2, :on)} {BOLD}{$2}{OFF}{emphasise(~$3)}" }
        # a card's heading: the mark stands in for PROMISE or FOUNDATION
        elsif $l ~~ / ^ ('PROMISE' | 'FOUNDATION') ' ' (\S+) (\h*) $ / { $l = "{mark-shown(~$1, :on)} {BOLD}{$1}{OFF}{$2}" }
        # the field labels (WHERE is the earlier clauses form's), wherever they lead a line, and the two questions
        elsif $l ~~ / ^ (\h*) ('CHANGES REQUIRE' | 'CHECKED WITH' | 'WHEN' | 'WHERE' | 'ALWAYS' | 'PROTECTS') (':' | ' before:' | ' after:' | \h | $) (.*) $ / { $l = "{$0}{BOLD}{$1}{OFF}{$2}{$3}" }
        elsif $l ~~ / ^ ('IS FOR WHAT?' | 'IS FOR WHO?') (.*) $ / { $l = "{BOLD}{$0}{OFF}{$1}" }
        # comments, dimmed; the rule-off too
        elsif $l ~~ / ^ '#' / { $l = "{DIM}{$l}{OFF}" }
        # the check's marks, and the gate's
        elsif $l ~~ / ^ (\h*) '✓' (.*) $ / { $l = "{$0}$g✓{OFF}{emphasise(~$1)}" }
        elsif $l ~~ / ^ (\h*) '✗' (.*) $ / { $l = "{$0}{RED}✗{OFF}{emphasise(~$1)}" }
        elsif $l ~~ / ^ (\h*) '?' ' ' (.*) $ / { $l = "{$0}{AMBER}?{OFF} {emphasise(~$1)}" }
        # verdicts and the lines that open a section
        elsif $l ~~ / ^ ('OK ' | 'NOT YET ') / { $l = "{BOLD}{$l}{OFF}" }
        # every header: the icon, then 'iz4', the command and the colon in bold
        elsif $l ~~ / ^ (['◈' | '*']) (' iz4' [' ' <-[:\s]>+]* ':') (.*) $ / { $l = "{$g}{$0}{OFF}{BOLD}{$1}{OFF}{emphasise(~$2)}" }
        # a block's title: the icon, then bold words
        elsif $l ~~ / ^ ('◈') ' ' (.*) $ / { $l = "{$g}{$0}{OFF} {BOLD}{$1}{OFF}" }
        # the help's commands, and the text logo's green centre
        elsif $l ~~ / ^ ('  iz4' [ ' ' <-[\h]>+ ]+?) (\h ** 2..* .*) $ / { $l = "{BOLD}{$0}{OFF}{$1}" }
        elsif $l ~~ / ^ ('  iz4 ' \S+) (.*) $ / { $l = "{BOLD}{$0}{OFF}{$1}" }
        else { $l = emphasise($l) }
        $l ~ $nl;
    }).join;
}

sub help-for(@words, Bool :$command = False --> List) is export {
    my $asked = @words.join(' ').trim.lc;
    return (help-index(), True) if $asked eq '';
    return (help-more(), True) if $asked eq 'more' | 'all';
    return (help-machine(), True) if $asked eq 'machine' | 'tools';
    # a command that has gone, or one kept only for the earlier named form
    # (split, name; iz4 check on such a file still points at them): say
    # what took its place
    $asked = 'migrate' if $asked eq 'number' | 'split' | 'name';
    $asked = 'protects' if $asked eq 'because';
    with topic($asked) { return (help-topic($_), True) }
    # 'iz4 help gate install': the action is part of the command it belongs to
    my @w = $asked.words;
    for (1 ..^ @w.elems).reverse -> $n {
        with topic(@w.head($n).join(' ')) { return (help-topic($_), True) }
    }
    # 'check' is two commands for tools as well as one for people: show the one asked for, then name the others
    my @under = topics().grep({ .name.starts-with("$asked ") });
    if @under {
        my @l = "iz4 $asked has more than one form:", '';
        @l.push: sprintf('  iz4 %-14s %s', .name, .summary) for @under;
        return (@l.join("\n") ~ "\n", True);
    }
    my @near = topics().grep({ .name.contains($asked) || $asked.contains(.name.words[0])
                               || distance($asked, .name) <= 2 }).head(3);
    # a mistyped command is offered the command; a mistyped 'iz4 help X' the help
    my $hint = @near ?? " Did you mean: {@near.map({ ($command ?? 'iz4 ' !! 'iz4 help ') ~ .name }).join(', ')}?" !! '';
    # one thing to read, not the whole list again
    ("There is no iz4 command '$asked'.$hint\n'iz4 help' lists the commands.\n", False);
}
