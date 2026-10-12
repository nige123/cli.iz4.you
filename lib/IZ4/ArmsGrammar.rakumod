#| The three-arm form of an IZ4 file, as a grammar.  This is the
#| specification of the form: what the parser accepts is exactly what is
#| written here, and docs/format.md restates it in prose.
#|
#|     IZ4 jobs.example.com
#|
#|     IS FOR WHAT?  Helping people find work they love to do.
#|     IS FOR WHO?   People looking for work.
#|
#|     private-stays-private:
#|       WHERE:    a profile marked private could reveal anything beyond its owner
#|       ALWAYS:   Only its owner, and the people they choose, may learn
#|                 what it reveals.
#|       PROTECTS: the owner's privacy, and their control over disclosure
#|
#| A file is the header line 'IZ4 domain', then blank lines, comments, the
#| two questions and invariants.  An invariant is a name and a colon alone
#| on a line at column 0, then its arms: WHERE (the situation it applies
#| in), ALWAYS (what must remain true there) and PROTECTS (what must not be
#| defeated).  An arm is its label and a colon, after any indentation, then
#| text that may wrap onto the lines below it.  Indentation is only for
#| the eye: a file with every line at column 0 reads the same.
#|
#| What is a line's job is decided by its start alone: a lower-case name
#| and a colon is an invariant, WHERE:, ALWAYS: and PROTECTS: are arms, a
#| line of '#' is a comment, a blank line ends the text of an arm, and
#| anything else continues the arm above it.  A comment between an arm's
#| lines does not end the arm.
#|
#| Like IZ4::Grammar it is forgiving of mistakes on purpose, so that one
#| parse can report every problem by line: the productions marked 'error'
#| accept what a person might write by accident.  Whether a name is a
#| well-formed one, and whether every arm is there, is judged in
#| IZ4::Document.
unit grammar IZ4::ArmsGrammar;

token TOP { ^ <prelude>* <header> <item>* $ }

token prelude { <blank> || <comment> }
token header  { 'IZ4' \h+ <domain> \n }
token domain  { \N+ }

# Ordered alternation: the first that matches wins.
token item {
    || <blank>
    || <comment>
    || <purpose>
    || <invariant>
    || <stray-arm>      # error: an arm with no invariant name above it
    || <stray>          # error: text where a name, label or question was expected
}

token blank   { \h* \n }
token comment { \h* '#' \N* \n }

# IS FOR WHAT? and IS FOR WHO?: the answer on the same line, or below.
token purpose-start { 'IS FOR' \h+ [ 'WHAT' || 'WHO' ] <!before \w> }
token purpose { 'IS FOR' \h+ $<which>=[ 'WHAT' || 'WHO' ] <!before \w> $<asked>=['?']? \h* $<first>=[\N*] \n <cont>* }

# An invariant: its name, then its arms.  Blank lines and comments may sit
# between them; the name of the next invariant, or anything that is not an
# arm, ends it.
token invariant { <heading> [ <blank> || <comment> || <arm> ]* }
token heading   { ^^ $<name>=[ <[a..z 0..9]> <[\w.\-]>* ] ':' \h* \n }

# FOR, RULE and BECAUSE (iz4 0.18) and HOLDS (0.19) are labels earlier
# versions wrote; still read, and renamed by 'iz4 migrate'.
token arm-label { 'WHERE' || 'ALWAYS' || 'PROTECTS' || 'HOLDS' || 'FOR' || 'RULE' || 'BECAUSE' }

# An arm backtracks over comments so that ones after its last line are not
# taken for its text.
regex arm { \h* <arm-label> ':' \h* $<first>=[\N*] \n [ <comment>* <cont> ]* }

# A continuation line: not blank, not a comment, not the start of anything.
token cont {
    <!before \h* \n>
    <!before \h* '#'>
    <!before <heading>>
    <!before \h* <arm-label> ':'>
    <!before <purpose-start>>
    \N* \n
}

token stray-arm { \h* <arm-label> ':' \N* \n <cont>* }
token stray     { \N* \n }
