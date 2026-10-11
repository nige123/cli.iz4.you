unit module IZ4::Assist;

#| Agent-assisted conveniences: suggest, review and test drafting.
#|
#| CONVENIENCE LAYER.  Everything here asks an agent for an opinion, and
#| reaching an agent is not iz4's knowledge: it is done through
#| IZ4::Launcher, which hands the prompt to 321 (or to the person's own
#| IZ4_AGENT_CMD).  The prompts themselves and the parsing of replies are
#| plain text work and live with the core modules they serve; only the
#| asking is here, so no core module ever reaches an agent or a harness.
#| What comes back is an opinion for a person to approve, never a finding.

use IZ4;
use IZ4::Document;
use IZ4::Review;
use IZ4::Evidence;
use IZ4::Launcher;

#| One agent pass over the repository.  Dies when the agent fails; a
#| reply with no usable lines is an honest 'nothing found'.

sub agent-suggest(IO::Path $dir = $*CWD, Str :$cmd, Str :$current = '' --> Hash) is export {
    my $prompt = suggest-prompt(:$current, evidence => gather-context($dir));
    die NO-AGENT-RUNNER unless agent-reachable(:$cmd);
    note "asking agent ({$cmd // agent-label()}) for candidate invariants in {$dir.resolve} ...";
    parse-suggestions(ask-agent($prompt, :root($dir), :$cmd));
}


#| A first draft of what this is for and who it is for.  Dies when the
#| agent fails; an empty hash when its reply had no usable answer.
sub agent-purpose(IO::Path $dir = $*CWD, Str :$cmd --> Hash) is export {
    die NO-AGENT-RUNNER unless agent-reachable(:$cmd);
    parse-purpose(ask-agent(purpose-prompt(evidence => gather-context($dir)), :root($dir), :$cmd));
}

#| New words for an invariant the software has moved on from.  Str when
#| the agent could not say; dies when it fails.
sub agent-reword(IO::Path $root, Str :$id!, Str :$text!, Str :$because = '', Str :$failure = '', Str :$cmd --> Str) is export {
    die NO-AGENT-RUNNER unless agent-reachable(:$cmd);
    parse-reword(ask-agent(reword-prompt(:$id, :$text, :$because, :$failure, evidence => gather-context($root)), :$root, :$cmd));
}

#| Ask the agent command for a draft.  Dies when the agent fails.
sub agent-draft($doc, $inv, IO::Path $root, Str :$lang!, Str :$path!, Str :$cmd, Str :$layout = '' --> Hash) is export {
    die NO-AGENT-RUNNER unless agent-reachable(:$cmd);
    my $prompt = draft-prompt($doc, $inv, :$lang, :$path, example => example-test($root), :$layout);
    parse-draft(ask-agent($prompt, :$root, :$cmd));
}


#| One agent pass over the change.  Dies when the agent fails.
sub agent-review(IO::Path $iz4, Str :$diff!, Str :$what!, Str :$cmd --> Hash) is export {
    my $doc = IZ4::Document.load($iz4);
    my $prompt = review-prompt(effective => effective-text($doc), :$diff, :$what);
    die NO-AGENT-RUNNER unless agent-reachable(:$cmd);
    note "asking agent ({$cmd // agent-label()}) to review $what ...";
    parse-review(ask-agent($prompt, :root($iz4.parent), :$cmd));
}

