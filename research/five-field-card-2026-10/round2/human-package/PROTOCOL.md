# Human readability test: protocol

Four blind versions of one ten-promise IZ4 for `app.example.com`, each with the
five foundation promises: `version-A.IZ4` to `version-D.IZ4`. The mapping from
letter to format is in `KEY-do-not-show-readers.json`; the facilitator opens it
only after the session. `record-sheet.csv` has a row per reader, version and
task. No part of this has been run yet.

## Readers

Eight to ten. Mix developers, product owners, and at least two people who do
not write code. Nobody who has seen an IZ4 before. Each reader sees all four
versions, in a rotated order (ABCD, BCDA, CDAB, DABC, then repeat).

## Setup

Plain terminal or editor, 80 columns, no syntax colouring. Say only: "This
file belongs to a software project. Read it as you would before changing the
software." Explain nothing about the format. Do not answer questions about it
until the end.

## Tasks, timed per version

Start the clock when the file appears; stop when the reader answers.

1. Thirty seconds with the file, then it is taken away: what is this file for?
2. Find the promise about sign-in codes. In what situation does it apply?
3. What must always be true about it?
4. Who or what does it protect?
5. May a developer change its wording without asking anyone? What told you?
6. If a test for it fails, does the change go in?
7. Does the file tell you whether that promise is currently kept?
8. Find a promise whose wording may be changed without approval. May a
   developer write code that breaks it, without telling anyone?
9. Which promises can nobody in this project change?
10. Scan: how many promises say a failing test blocks the change? Name them.
11. Point to the line that answered 5, and the line that answered 6.

## After all four

- Rank the four: easiest to read; easiest to skim for one promise; the one you
  would rather edit; the one you would least like to read before every change.
- Does the shift from the first lines of a promise to the lines about changing
  and checking it feel natural, or like a different document?
- In the versions that have it, does FOUNDATION as a heading help?
- Would "MUST" read better than "ALWAYS"? Show one line both ways.
- One thing you would change in your preferred version.

## Key

- Sign-in code: applies when a code is submitted; works at most once, before
  expiry, including concurrent submissions; protects accounts from
  unauthorised access; wording needs signed approval; a failing test blocks
  the change; the file never says whether it is kept.
- Task 8: no. Permission to edit the words is not permission to break the
  promise. (Versions that say so on the card count as "told"; note whether the
  reader found it or inferred it.)
- Task 9: the five promises under iz4.you.
- Task 10: four in the five-field versions and the paragraph version
  (single-use-code, export-is-complete, search-respects-sharing,
  backups-restore). In the current format this needs the mode line and the
  heading words; record the time and the answer.

## Record

Per reader, version and task: seconds, answer, correct or not, the line
pointed to, any confusion in their words. Then the rankings.

## What would count

A version is better for people if tasks 2 to 11 are faster with no more wrong
answers, most readers rank it easiest, and its length is not named as a cost
by most readers. Report counts and times. Do not average away a version that
one reader found misleading; report the misreading.
