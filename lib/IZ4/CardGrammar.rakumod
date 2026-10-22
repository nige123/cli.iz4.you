#| The promise-card form of an IZ4 file, as a grammar.  This is the
#| specification of the form: what the parser accepts is exactly what is
#| written here, and docs/format.md restates it in prose.
#|
#|     IZ4 jobs.example.com
#|
#|     IS FOR WHAT?  Helping people find work they love to do.
#|     IS FOR WHO?   People looking for work.
#|
#|     PROMISE private-stays-private.jobs.example.com
#|
#|       WHEN      a profile marked private could reveal anything beyond its owner
#|       ALWAYS    only its owner, and the people they choose, may learn what it
#|                 reveals
#|       PROTECTS  the owner's privacy, and their control over disclosure
#|
#|       CHANGES REQUIRE signed human approval for the exact change
#|       CHECKED WITH    linked tests; failures block commit
#|
#| A file is the header line 'IZ4 domain', then blank lines, comments, the
#| two questions and cards.  A card is a heading alone on a line at column
#| 0, PROMISE or FOUNDATION and the promise's whole name, then its five
#| fields: WHEN (the situation it applies in), ALWAYS (what must remain
#| true there), PROTECTS (whose what must not be defeated), CHANGES REQUIRE
#| (what a change to its words needs) and CHECKED WITH (what is checked,
#| and what a failure does).  A field is its label after any indentation,
#| with no colon, then either its words on the same line, wrapping onto
#| the lines below, or nothing on the line and a dashed list below it: one
#| item per line, each beginning with '-', each wrapping onto the lines
#| below it.  Indentation is only for the eye.
#|
#| What is a line's job is decided by its start alone: PROMISE or
#| FOUNDATION and a name is a heading, one of the five labels is a field,
#| '-' and a space is a list item, a line of '#' is a comment, a blank line
#| ends a field, and anything else continues the field or item above it.
#| A comment between a field's lines does not end the field.
#|
#| Like the earlier grammars it is forgiving of mistakes on purpose, so
#| that one parse can report every problem by line: the productions marked
#| 'error' accept what a person might write by accident.  Whether a name is
#| well formed, whether every field is there and in order, whether a list
#| is allowed where it stands, and whether the governance fields carry one
#| of the fixed values, is judged in IZ4::Document.
unit grammar IZ4::CardGrammar;

token TOP { ^ <prelude>* <header> <item>* $ }

token prelude { <blank> || <comment> }
token header  { 'IZ4' \h+ <domain> \n }
token domain  { \N+ }

# Ordered alternation: the first that matches wins.
token item {
    || <blank>
    || <comment>
    || <purpose>
    || <card>
    || <stray-field>       # error: a field with no heading above it
    || <stray>             # error: text where a heading, label or question was expected
}

token blank   { \h* \n }
token comment { \h* '#' \N* \n }

# IS FOR WHAT? and IS FOR WHO?: the answer on the same line, or below.
token purpose-start { 'IS FOR' \h+ [ 'WHAT' || 'WHO' ] <!before \w> }
token purpose { 'IS FOR' \h+ $<which>=[ 'WHAT' || 'WHO' ] <!before \w> $<asked>=['?']? \h* $<first>=[\N*] \n <cont>* }

# A card: its heading, then its fields.  Blank lines and comments may sit
# between them; the next heading, or anything that is not a field, ends it.
token card    { <heading> [ <blank> || <comment> || <field> ]* }
token heading { ^^ $<kind>=[ 'PROMISE' || 'FOUNDATION' ] \h+ $<name>=[ \S+ ] \h* \n }

# The five labels, the two-word ones first so that they match whole.
token label { 'CHANGES REQUIRE' || 'CHECKED WITH' || 'WHEN' || 'ALWAYS' || 'PROTECTS' }

# A field: its label, then its words on the same line or nothing, then
# list items and continuation lines.  It backtracks over comments so that
# ones after its last line are not taken for its text.
regex field { \h* <label> <!before \w> [ \h+ $<first>=[\N*] ]? \h* \n [ <comment>* [ <li> || <cont> ] ]* }

# A list item: a dash and a space, then its words; its indentation is kept
# so that a nested list can be refused.
token li { $<indent>=[\h*] '-' \h+ $<text>=[\N*] \n }

# A continuation line: not blank, not a comment, not a list item, not the
# start of anything.
token cont {
    <!before \h* \n>
    <!before \h* '#'>
    <!before \h* '-' \h>
    <!before <heading>>
    <!before \h* <label> [ \h | \n ]>
    <!before <purpose-start>>
    \N* \n
}

token stray-field { \h* <label> <!before \w> \N* \n [ <li> || <cont> ]* }
token stray       { \N* \n }
