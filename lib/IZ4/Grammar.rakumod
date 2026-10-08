#| The IZ4 file format, as a grammar.  This is the specification: what
#| the parser accepts is exactly what is written here, and docs/format.md
#| restates it in prose.
#|
#|     IZ4
#|
#|     IS FOR WHAT?
#|     Helping people find work they love to do.
#|
#|     IS FOR WHO?
#|     People looking for work.
#|
#|     INVARIANT visible-by-choice.jobs.example.com
#|     People control whether their profile is visible.
#|
#|     BECAUSE
#|     Looking for work should not mean surrendering privacy.
#|
#| A file is the header line IZ4, then any number of blank lines, comment
#| lines and blocks.  A block is a keyword line at column 0 followed by
#| its text lines; the text runs until a blank line, a comment or the
#| next keyword.  There are four keywords: IS FOR WHAT?, IS FOR WHO?,
#| INVARIANT name and BECAUSE.  What follows INVARIANT on its line is the
#| invariant's label; that a label is a well-formed, unreserved name is
#| judged in IZ4::Document, so every problem with one is reported by line.
#|
#| The grammar is deliberately forgiving: the productions marked 'error'
#| and 'warning' below accept what a person might write by mistake, so
#| that one parse can report every problem with its line number instead
#| of stopping at the first.  Which of them are errors and which are
#| warnings is decided in IZ4::Document.
unit grammar IZ4::Grammar;

token TOP { ^ <prelude>* <header>? <item>* $ }

# Blank and comment lines may precede the header.
token prelude { <blank> || <comment> }
token header  { 'IZ4' \h* \n }

# Ordered alternation (||): the first that matches wins, so a keyword is
# a block before it is a capitals line, and a capitals line is a block
# before it is stray text.
token item {
    || <blank>
    || <comment>
    || <block>
    || <unknown-block>      # warning: a capitals line that is not a keyword
    || <indented-keyword>   # error: a keyword that is not at column 0
    || <legacy-section>     # error: the earlier format ('gist:', 'invariants:')
    || <stray>              # error: text where a keyword was expected
}

token blank   { \h* \n }
token comment { '#' \N* \n }

# A block: its keyword line, then its text lines.
token block { <keyword> \h* \n <text-line>* }

token keyword { <for-what> || <for-who> || <invariant> || <because> }
token for-what  { 'IS FOR WHAT' <asked>? <!before \S> }
token for-who   { 'IS FOR WHO'  <asked>? <!before \S> }
token asked     { '?' }
token invariant { 'INVARIANT' [ \h+ <label> ]? <!before \S> }
token label     { \S+ [ \h+ \S+ ]* }
token because   { 'BECAUSE' <!before \S> }

# A text line: anything that is not blank, not a comment, not a keyword
# line (an INVARIANT with its lower-case name is not a capitals line, so
# it is named here), not a capitals line (which would start another
# block) and not an indented keyword (which is reported, so a
# mis-indented BECAUSE is never swallowed).
token text-line { <!before \h* \n> <!before '#'> <!before <keyword> \h* \n> <!before <caps-line>> <!before \h+ <keyword> \h* \n> \N* \n }

# Any line of capitals and digits is a block header, so the format can
# grow; one that is not a known keyword is kept and reported.
token caps-line     { <[A..Z]> <[A..Z 0..9 \h]>* '?'? \h* \n }
token unknown-block { <caps-line> <text-line>* }

token indented-keyword { \h+ <keyword> \h* \n <text-line>* }
token legacy-section   { <[a..z]> <[\w\-]>* ':' \h* \n }
token stray            { \N* \n }
