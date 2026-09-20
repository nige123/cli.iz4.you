unit module IZ4::Coach;

#| Coaching for invariants.  Most developers have spent their careers
#| writing requirements, tests, tickets and implementation notes, and
#| will naturally type those into IZ4.  This module helps them find the
#| enduring truth underneath, or notice there is none.
#|
#| It behaves like a thoughtful senior developer asking one useful
#| question at a time, never a questionnaire.  Everything here is
#| deterministic and offline: a few plain heuristics, never a model.
#| A heuristic can only raise a question; the project owner decides what
#| must remain true, and nothing is added without their confirmation.

use IZ4::Document;

#| The golden test, the question at the heart of every coaching exchange.
constant GOLDEN-TEST is export =
    'If the whole system were rewritten tomorrow, would we regret not '
    ~ 'telling the people and agents rebuilding it this?';

#| The opening question when there is no candidate yet.
constant OPENING is export =
    'What must remain true even if this system is completely rewritten?';

# ------------------------------------------------------------ heuristics

#| Mechanisms that usually protect something worth stating: ask what
#| must stay true if the mechanism changes, rather than just saying no.
my @MECHANISMS = <
    argon2id argon2 bcrypt scrypt pbkdf2 webauthn passkey totp 2fa mfa
    tls https encryption encrypted e2ee csrf ssr backup
>;
my @MECHANISM-PHRASES = 'server-side rendering', 'rate limiting', 'audit log',
    'two-factor', 'end-to-end encryption', 'soft delete';

#| Technology and implementation words: today's choices, not intent.
my @TECHNOLOGY = <
    postgres postgresql mysql mariadb sqlite mongo mongodb redis memcached
    elasticsearch opensearch kafka rabbitmq sqs react vue svelte angular
    nextjs next.js nuxt nodejs node.js deno rails django flask fastapi laravel
    mojolicious raku perl python ruby php java javascript typescript golang
    kotlin elixir docker kubernetes k8s terraform ansible aws gcp azure s3
    heroku vercel netlify cloudflare nginx graphql grpc json yaml xml orm
    microservice microservices monolith cron sidekiq celery tailwind css
    html htmx jquery webpack vite stripe twilio sendgrid jwt uuid sql nosql
>;
my @IMPLEMENTATION-PHRASES =
    /:i^ \s* we \s+ use <|w>/, /:i <|w> built \s+ (with|on|in) <|w>/,
    /:i <|w> written \s+ in <|w>/, /:i <|w> implemented \s+ (with|in|using|as) <|w>/,
    /:i <|w> (database \s+ table|db \s+ table|column|endpoint|library|framework|schema \s+ migration|cache\w*) <|w>/;

my @REQUIREMENT-PATTERNS =
    /:i <|w> \d+ \s* (results?|items?|rows?|per \s+ page|ms|milliseconds?|seconds?|secs?|minutes?|mins?|hours?|px|pixels?|characters?|chars?|retries|attempts|mb|gb|kb|\%|percent) <|w>/,
    /:i <|w> per \s+ page <|w>/,
    /:i <|w> (button|colou?r|font|dropdown|modal|tooltip|page \s+ size|timeout|pagination|sort \s+ order) <|w>/,
    /:i <|w> (displays?|shows?) \s+ (a|an|the|\d+) <|w>/;

my @TASK-PATTERNS =
    /:i ^ \s* (add|implement|build|create|refactor|fix|migrate|upgrade|write|remove|rename|update|set \s+ up|todo|to \s+ do) <|w>/,
    /:i <|w> (todo|next \s+ sprint|story \s+ points?|acceptance \s+ criteria|ticket|backlog) <|w>/,
    /:i <|w> by \s+ (monday|tuesday|wednesday|thursday|friday|next \s+ week|the \s+ end \s+ of) <|w>/,
    /:i ^ \s* given <|w> .* <|w> when <|w> .* <|w> then <|w>/,
    /:i <|w> we \s+ (will|plan \s+ to|need \s+ to|should \s+ (add|build|implement)) <|w>/;

sub find-word(Str $text, @words, Bool :$plural = False --> Str) {
    for @words -> $w {
        # a whole word, never part of a longer one
        my $m = $plural
            ?? $text.match(/:i <!after <[a..z A..Z 0..9]>> $w s? <!before <[a..z A..Z 0..9]>> /)
            !! $text.match(/:i <!after <[a..z A..Z 0..9]>> $w <!before <[a..z A..Z 0..9]>> /);
        return ~$m if $m;
    }
    Str;
}

#| True when the text states independence from a technology ("works
#| without client-side JavaScript", "never depends on AWS"): that is a
#| statement of intent about the technology, not a choice of it.
sub independent-of(Str $text, Str $word --> Bool) {
    my $at = $text.lc.index($word.lc) // return False;
    my $before = $text.substr(0, $at).lc;
    so $before ~~ /[without|no|independent \s+ of|regardless \s+ of|free \s+ of|never \s+ (need|needs|require|requires|depend|depends) [\s+ on]?|not \s+ (need|require|depend) [\s+ on]?] \s+ [<[a..z \-]>+ \s+]? $/;
}

#| What a candidate invariant most likely is.  Returns a hash with 'kind'
#| (implementation, mechanism, requirement, task, vague or candidate) and
#| 'signal', the words that raised the question.  Only a hint: the coach
#| turns it into one question, never a verdict.
sub assess-candidate(Str $text --> Hash) is export {
    my $t = $text.trim;

    for @TASK-PATTERNS -> $re {
        return %( kind => 'task', signal => ~$/ ) if $t ~~ $re;
    }
    with find-word($t, @MECHANISMS, :plural) -> $m {
        return %( kind => 'mechanism', signal => $m ) unless independent-of($t, $m);
    }
    for @MECHANISM-PHRASES -> $p {
        return %( kind => 'mechanism', signal => $p ) if $t.lc.contains($p) && !independent-of($t, $p);
    }
    with find-word($t, @TECHNOLOGY) -> $w {
        return %( kind => 'candidate', signal => Str ) if independent-of($t, $w);
        return %( kind => 'implementation', signal => $w );
    }
    for @IMPLEMENTATION-PHRASES -> $re {
        return %( kind => 'implementation', signal => ~$/.trim ) if $t ~~ $re;
    }
    for @REQUIREMENT-PATTERNS -> $re {
        return %( kind => 'requirement', signal => ~$/.trim ) if $t ~~ $re;
    }
    return %( kind => 'vague', signal => $t ) if $t.words < 3;
    %( kind => 'candidate', signal => Str );
}

my constant STOPWORDS = set <
    a an the and or but of to for in on at by with from as is are was were be
    been being it its they them their this that these those there must should
    has have had do does did not no never always can cannot will would shall
    may might so because since why then than we our us you your i he she his
    her him who whom which what when where how all any each every only just
    very really also still stay stays remain remains true
>;

sub content-words(Str $s --> Set) {
    $s.lc.comb(/<[a..z0..9]>+/).grep({ $_ ∉ STOPWORDS && .chars > 1 })
      .map({ .subst(/ 's' $/, '') }).Set;
}

#| Whether a BECAUSE explains anything.  'circular' when it only restates
#| the invariant ("Private profiles are private" because "they must be
#| private"); 'empty' when there is nothing; otherwise 'ok'.
sub assess-because(Str $invariant, Str $because --> Str) is export {
    my $b = ($because // '').trim;
    return 'empty' if $b eq '';
    my $bw = content-words($b);
    return 'circular' if $bw.elems == 0;
    return 'circular' if $bw ⊆ content-words($invariant);
    'ok';
}

# ------------------------------------------------------- reason splitting

#| Words that mark a sentence as saying why, not what: consequences and
#| stakes, the shapes a reason takes when it is folded into the invariant
#| instead of standing under BECAUSE.  Words that rules use as often as
#| reasons ("cannot", "nobody", "never", "fails") are left out on purpose,
#| so a rule is not mistaken for its reason.
my regex reason-cue {
    :i <|w> [ <!after [merely | just | simply | only | not] \s+> because | 'so that' | 'is what makes' | 'must be able to' | would
            | harm | 'at a loss' | matters | rely | relies | 'the point'
            | 'the whole point' | 'the reason' | 'the worst' | 'at stake' ] <|w>
}

#| A connective that joins a rule to its reason inside one sentence:
#| "X, because Y", "X so that Y", "X, so Y", "X, which is why Y".
my regex connective {
    [ \s* ',' \s* 'so' \s+ | \s* ',' \s* 'which is why' \s+
    | ','? \s+ <!after [merely | just | simply | only | not] \s+> [ because | 'so that' ] \s+ ]
}

#| A sentence with any bracketed aside removed: an aside can hold an
#| example or an incident ("... (it was dropped twice because ...)") that
#| is not the invariant's reason.
sub without-asides(Str $s --> Str) { $s.subst(/ \s* '(' <-[()]>* ')' /, '', :g) }

#| Split $text into sentences, keeping each sentence's own end mark.
sub sentences(Str $text --> List) is export {
    $text.trim.split(/ <?after <[.!?]> > \s+ <?before <[A..Z "']> > /).grep(*.chars).List
}

#| The reason folded into a candidate, if there is one.  Returns
#| (claim, reason); reason is Str (undefined) when nothing was found.
#| Two shapes are recognised, looking only at the last sentence: a
#| connective inside it ("X, because Y" / "X, so Y") splits it there; a
#| closing sentence that reads as the stakes ("A confidently wrong price
#| sells work at a loss.") moves whole.  Only a hint: what it finds is
#| shown to the owner, never assumed.
sub split-reason(Str $text --> List) is export {
    my $t = $text.trim;
    my @s = sentences($t);
    my $last = @s[*-1];
    my @head = @s[0 .. *-2];
    my $bare = without-asides($last);
    with $bare.match(/ ^ (.+?) <connective> (.+) $ /) -> $m {
        my ($claim, $reason) = ~$m[0], ~$m[1];
        $claim = $claim.trim.subst(/ <[,;:]> $ /, '').trim;
        # "X, so Y; Z": Y is the reason, Z is another rule that stays
        my $tail = '';
        if $reason ~~ / ^ (.+?) ';' \s+ (.+) $ / {
            ($reason, $tail) = ~$0, ~$1;
            $tail = $tail.substr(0, 1).uc ~ $tail.substr(1);
        }
        if $claim.words >= 3 && $reason.words >= 3 {
            $claim ~= '.' unless $claim ~~ / <[.!?]> $ /;
            $reason = $reason.substr(0, 1).uc ~ $reason.substr(1);
            $reason ~= '.' unless $reason ~~ / <[.!?]> $ /;
            return ((|@head, $claim, |($tail ?? $tail !! Empty)).join(' '), $reason);
        }
    }
    if @head && $bare ~~ &reason-cue && $last.words >= 4 {
        return (@head.join(' '), $last);
    }
    ($t, Str);
}

# ------------------------------------------------------------- coaching

#| An IS FOR answer, reshaped to sit inside a question: its first
#| sentence, without the full stop, and only when it is short enough to
#| read as a phrase; otherwise empty, so the caller uses plain words.
sub in-sentence(Str $s --> Str) {
    my $t = sentences($s // '').head // '';
    $t = $t.trim.subst(/ <[.!]>+ $/, '');
    $t.words <= 14 ?? $t !! '';
}

#| Parse a yes/no answer: True, False, or Bool (undefined) for 'not sure'.
sub yes-no(Str $answer, Bool :$default --> Bool) is export {
    my $a = ($answer // '').trim.lc;
    return $default if $a eq '' && $default.defined;
    return True  if $a ~~ /^ (y|yes|yep|yeah|sure|definitely) <|w>/;
    return False if $a ~~ /^ (n|no|nope|not \s+ really) <|w>/;
    Bool;
}

#| Coach one candidate towards an invariant, or away from IZ4.
#|
#| &ask takes a prompt and returns the person's answer (undefined at end
#| of input); &tell shows a line.  Returns a hash with 'outcome' - add,
#| not-iz4, needs-human or skipped - plus 'text' and 'because' when adding,
#| and 'advice' saying where non-IZ4 content belongs.
#|
#| The shape is: candidate, one useful challenge, refinement if needed,
#| the golden test, BECAUSE, confirm.  At most three refinements; the
#| person can leave at any question by pressing enter.
sub coach-invariant(
    :&ask!, :&tell!,
    Str :$candidate is copy,
    Str :$for-what, Str :$for-who,
    Int :$number,
    Str :$suggested-because is copy,
    --> Hash
) is export {
    my $who  = in-sentence($for-who)  || 'the people this is for';
    my $what = in-sentence($for-what) || 'what this is for';
    my sub answer(Str $prompt --> Str) { (ask($prompt) // '').trim }

    without $candidate {
        tell(OPENING);
        $candidate = answer('> ');
        return %( outcome => 'skipped' ) if $candidate eq '';
    }

    # a reason folded into the candidate is a good sign; take it out and
    # offer it as the BECAUSE
    {
        my ($claim, $reason) = split-reason($candidate);
        if $reason.defined {
            tell("It sounds like the reason is in there too. Keeping the invariant as: $claim");
            $candidate = $claim;
            $suggested-because //= $reason;
        }
    }

    my $settled = False;
    for ^4 -> $round {
        my %a = assess-candidate($candidate);
        given %a<kind> {
            when 'candidate' { $settled = True }
            when 'vague' {
                my $more = answer("Say a little more: what exactly must remain true, and for whom?\n> ");
                return %( outcome => 'skipped' ) if $more eq '';
                $candidate = $more;
            }
            when 'mechanism' {
                tell("It sounds like {%a<signal>} is how it is done today.");
                my $refined = answer("What must remain true if {%a<signal>} is replaced? "
                    ~ "(enter if nothing: then it stays out of IZ4)\n> ");
                if $refined eq '' {
                    tell("Then leave it out of IZ4: record {%a<signal>} in an ADR or the developer docs.");
                    return %( outcome => 'not-iz4', advice => 'ADR or developer documentation' );
                }
                $candidate = $refined;
            }
            when 'implementation' {
                tell("That sounds like an implementation choice rather than an invariant.");
                my $replaceable = yes-no(answer(
                    "If {%a<signal>} were replaced tomorrow, could it still serve "
                    ~ "the same people and purpose? [y/n] "));
                without $replaceable {
                    tell("That depends on intent only the project owner can settle. Nothing added.");
                    return %( outcome => 'needs-human' );
                }
                if $replaceable {
                    tell("Then this probably doesn't belong in IZ4. Consider recording it in an ADR or developer documentation instead.");
                    my $refined = answer("Does it protect something that must stay true whatever replaces it? "
                        ~ "Say what, or press enter to leave it out.\n> ");
                    return %( outcome => 'not-iz4', advice => 'ADR or developer documentation' )
                        if $refined eq '';
                    $candidate = $refined;
                }
                else {
                    my $refined = answer("Then something about it must survive. What must remain true, "
                        ~ "whatever the technology? (enter to keep it as written)\n> ");
                    if $refined eq '' { $settled = True } else { $candidate = $refined }
                }
            }
            when 'requirement' {
                tell("That reads like a requirement or setting for today's product, not enduring intent.");
                my $matters = yes-no(answer("Would $who be let down if it changed? [y/n] "));
                without $matters {
                    tell("That depends on intent only the project owner can settle. Nothing added.");
                    return %( outcome => 'needs-human' );
                }
                unless $matters {
                    tell("Then it probably doesn't belong in IZ4: pin it with a test, or keep it in config or the README.");
                    return %( outcome => 'not-iz4', advice => 'tests, config or the README' );
                }
                my $refined = answer("What exactly would let them down? Say it as what must remain true "
                    ~ "(enter to keep it as written).\n> ");
                if $refined eq '' { $settled = True } else { $candidate = $refined }
            }
            when 'task' {
                tell("That reads like work to do. IZ4 records what must stay true, not tasks: track it in your issues or plan.");
                my $refined = answer("Is there a lasting truth behind it? Say it, or press enter to leave it out.\n> ");
                return %( outcome => 'not-iz4', advice => 'issues or a plan' ) if $refined eq '';
                $candidate = $refined;
            }
        }
        last if $settled;
    }
    unless $settled {
        tell("This still reads like detail rather than enduring intent. Nothing added: settle it with the project owner.");
        return %( outcome => 'needs-human' );
    }

    my $regret = yes-no(answer(GOLDEN-TEST ~ ' [y/n] '));
    without $regret {
        tell("That depends on product intent only the project owner can settle. "
            ~ "Nothing added: ask them, then run 'iz4 add' again.");
        return %( outcome => 'needs-human' );
    }
    unless $regret {
        tell("Then it probably doesn't belong in IZ4.");
        return %( outcome => 'not-iz4', advice => 'the README, tests or developer documentation' );
    }

    # the suggestion is shown exactly as it would be written
    my $hint = ($suggested-because // '').trim;
    $hint = $hint.substr(0, 1).uc ~ $hint.substr(1) if $hint ne '';
    my $because = answer("BECAUSE: why must this survive? How does it matter to $who, or to $what?"
        ~ ($hint ne '' ?? "\n(enter to use the suggestion: $hint)" !! '') ~ "\n> ");
    $because = $hint if $because eq '' && $hint ne '';
    if assess-because($candidate, $because) eq 'circular' {
        tell("That restates the invariant. Who would be harmed, surprised or let down if it stopped being true, and why?");
        $because = answer('> ');
        if assess-because($candidate, $because) ne 'ok' {
            tell("Leaving BECAUSE out for now: add one when the reason is clear.");
            $because = '';
        }
    }
    elsif $because eq '' {
        tell("Without a BECAUSE this is easy to remove by accident; you can add one later.");
    }

    my $label = $number.defined ?? "INVARIANT $number" !! 'an invariant';
    my $confirm = yes-no(answer("Add it as $label? [Y/n] "), :default);
    return %( outcome => 'skipped' ) unless $confirm;
    %( outcome => 'add', text => $candidate, because => ($because eq '' ?? Str !! $because) );
}
