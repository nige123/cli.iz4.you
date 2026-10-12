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
      'Drafts what this is for and who it is for with the agent you already use, and you keep each answer or type your own. It then sets up the commit hook and your agents, and offers to find a first invariant. A script gives both answers, and the domain it names invariants under: --for-what=... --for-who=... --namespace=your.domain',
      'iz4 init'),
    t('add', EVERY-DAY, 'find an invariant, one question at a time',
      ['iz4 add', 'iz4 add invariant RULE --for=WHAT --name=NAME --because=WHY', 'iz4 add for-what TEXT', 'iz4 add for-who TEXT'],
      'Alone, it coaches you to one invariant in three questions: who or what it covers (FOR), what must remain true for them (RULE), and why (BECAUSE), then its name. With the rule, it adds it at once. The name is a few lower-case words joined by hyphens.',
      "iz4 add invariant 'An order is never charged twice.' --for='every order' --name=charged-once"),
    t('check', EVERY-DAY, 'what is true of the file, and what to do next',
      ['iz4 check', 'iz4 check --strict'],
      'Ticks what is true, marks what is not, and lists the next steps in order. It fails only on errors; --strict fails on anything marked. It never says the software keeps its invariants: it cannot know.',
      'iz4 check'),
    t('show', EVERY-DAY, 'read the IZ4, or one part of it',
      ['iz4 show', 'iz4 show for-what | for-who | invariants', 'iz4 show invariant NAME'],
      'The first part of a name will do where only one invariant begins with it. 0 to 4, or zero, finds the foundation by its order.',
      'iz4 show invariant charged-once'),
    t('test', EVERY-DAY, 'a test for each invariant that has none',
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
    t('mode', CHANGE, 'MVP while the invariants settle, solid when they hold',
      ['iz4 mode', 'iz4 mode mvp', 'iz4 mode solid'],
      'In MVP mode a change to your own invariants does not wait for a yes, a failing test of one does not hold a commit, and iz4 says one line. Solid is the opposite: each change waits for you. The foundation holds in both. The mode is a line in the IZ4, so everyone sees it.',
      'iz4 mode mvp'),
    t('withdraw', 'Shaping an invariant', 'take an invariant out, with its tests',
      ['iz4 withdraw NAME'],
      'Shows the invariant and the tests that exist only for it, asks once, and removes them. Git keeps all of it. The name is retired for good. --keep-tests leaves the tests.',
      'iz4 withdraw charged-once'),

    t('because', 'Shaping an invariant', 'say why an invariant must survive',
      ['iz4 because NAME WHY'],
      'An invariant with no reason is easy to remove by accident. --replace changes one already given.',
      "iz4 because charged-once 'It costs people money and trust.'"),
    t('reach', 'Shaping an invariant', 'say what an invariant covers: its FOR',
      ['iz4 reach NAME WHAT'],
      'Who or what the invariant covers. The rule holds throughout that reach, and a boundary only counts if it is written in the rule. Say it in the words you would use out loud.',
      "iz4 reach private-stays-private 'private profiles'"),
    t('split', 'Shaping an invariant', 'move a reason out of an invariant and under BECAUSE',
      ['iz4 split', 'iz4 split NAME'],
      'For an invariant whose own sentence says why. The words are yours, only moved. Alone, it does every one.',
      'iz4 split charged-once'),
    t('name', 'Shaping an invariant', 'name an INVARIANT that has no name',
      ['iz4 name LINE NAME'],
      'LINE is the line the INVARIANT is on; iz4 check tells you. A name already given is never changed.',
      'iz4 name 42 charged-once'),
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

    t('migrate', 'Moving forward', 'move an IZ4 to its newer form',
      ['iz4 migrate', 'iz4 migrate preview', 'iz4 migrate --reach=NAME=WHAT|NAME=WHAT', 'iz4 migrate --namespace=DOMAIN --names=5=NAME,6=NAME'],
      'A numbered IZ4 gets names: the foundation by its fixed order, and you choose one for each of your own. A named IZ4 gets the three-arm form: header domain, and you say what each invariant covers (FOR). Your own RULE and BECAUSE are never touched. preview shows what would change.',
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

    t('version', 'The tool', 'which iz4 this is', ['iz4 version'], '', 'iz4 version'),
    t('update', 'The tool', 'bring iz4 up to date',
      ['iz4 update', 'iz4 update check'], 'check only says whether a newer one exists.', 'iz4 update check'),
    t('help', 'The tool', 'this help',
      ['iz4 help', 'iz4 help COMMAND', 'iz4 help more', 'iz4 help machine'], '', 'iz4 help add'),

    t('discover', 'For tools', 'does an IZ4 govern this directory?', ['iz4 discover --json'], '', 'iz4 discover --json'),
    t('context', 'For tools', 'what to tell an agent before it works', ['iz4 context --json'], '', 'iz4 context --json'),
    t('check action', 'For tools', 'does one action need a person?',
      ['iz4 check action --json'], 'The action is JSON on standard input: operation, target, parameters.', "echo '\{\"operation\":\"write\",\"target\":\"IZ4\"\}' | iz4 check action --json"),
    t('check change', 'For tools', 'does this change alter a commitment?',
      ['iz4 check change --worktree --json', 'iz4 check change --staged --json'], 'The gate, in the vocabulary a tool reads. --worktree looks at uncommitted work and touches no index.', 'iz4 check change --worktree --json'),
    t('verify', 'For tools', 'what can be established about finished work',
      ['iz4 verify --worktree --json', 'iz4 verify --worktree --summary=FILE --json'], 'Structure, change, and, given the agent\'s last words, its report. Results are pass, warn, block or needs_human. docs/drivers.md', 'iz4 verify --worktree --json'),
    t('hook', 'For tools', 'what wiring made by an earlier iz4 still calls',
      ['iz4 hook EVENT'],
      'EVENT is session-start, pre-edit or stop. Reads the harness event as JSON, prints text for the model, and refuses with exit 2 and a reason. Kept so earlier wiring keeps working; the driver (321) wires harnesses now.',
      'iz4 hook EVENT < event.json'),
    )
}

sub topic(Str $name --> Topic) is export { topics().first({ .name eq $name }) // Topic }

#| The first screen: what iz4 is, the commands for everyday work, the
#| few for when intent changes, and where the rest is.  Nothing more.
sub help-index(--> Str) is export {
    my @l = 'iz4: what your software is for, who it is for, and what must stay true.', '';
    for EVERY-DAY, CHANGE -> $g {
        @l.push: $g;
        @l.push: sprintf('  iz4 %-10s %s', .name, .summary) for topics().grep({ .group eq $g });
        @l.push: '';
    }
    @l.push: 'iz4 help COMMAND    more on one command, with an example';
    @l.push: 'iz4 help more       the rest: reading, shaping, agents, the register';
    @l.join("\n") ~ "\n";
}

#| Everything not on the first screen, in small groups.  The commands a
#| tool calls are left to 'iz4 help machine'.
sub help-more(--> Str) is export {
    my @l;
    for topics().map(*.group).unique.grep({ $_ ne EVERY-DAY && $_ ne CHANGE && $_ ne 'For tools' }) -> $g {
        @l.push: $g;
        @l.push: sprintf('  iz4 %-14s %s', .name, .summary) for topics().grep({ .group eq $g });
        @l.push: '';
    }
    @l.push: 'iz4 help COMMAND    more on one command, with an example';
    @l.push: 'iz4 help machine    the commands a tool calls';
    @l.join("\n") ~ "\n";
}

sub help-machine(--> Str) is export {
    my @l = 'For tools: what an environment driver, a hook or a CI job calls.', '';
    @l.push: sprintf('  iz4 %-14s %s', .name, .summary) for topics().grep({ .group eq 'For tools' });
    @l.push: '';
    @l.push: 'Each answers with a document (--json) and an exit code: 0 pass or warn,';
    @l.push: '2 a person must decide, 3 blocked, 1 the check could not run.';
    @l.push: 'docs/drivers.md has the contract.';
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
    my @l = "iz4 {$t.name}: {$t.summary}", '';
    @l.push: "  $_" for $t.usage;
    if $t.more ne '' { @l.push: ''; @l.append: wrap-at($t.more, 76) }
    if $t.example ne '' { @l.push: '', 'For example:', "  {$t.example}" }
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

sub help-for(@words --> List) is export {
    my $asked = @words.join(' ').trim.lc;
    return (help-index(), True) if $asked eq '';
    return (help-more(), True) if $asked eq 'more' | 'all';
    return (help-machine(), True) if $asked eq 'machine' | 'tools';
    # a command that has gone: say what took its place
    $asked = 'migrate' if $asked eq 'number';
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
    my $hint = @near ?? " Did you mean: {@near.map({ 'iz4 help ' ~ .name }).join(', ')}?" !! '';
    # one thing to read, not the whole list again
    ("There is no iz4 command '$asked'.$hint\n'iz4 help' lists the commands.\n", False);
}
