# Human readability test sheet: IZ4 promise formats

For a session with real readers. Nothing here has been run; the pilot used
models only, and model answers are not a substitute for this.

## Who

At least five readers, ideally ten: a mix of developers, product owners and
one or two people who do not write code. Nobody who has seen an IZ4 before.

## Materials

Three versions of the same file, ten promises plus the five foundation
promises, printed or opened in a plain terminal at 80 columns:

- A: today's format (`eval/files/G0-current--*.IZ4`, join two files to reach ten)
- B: the paragraph card (`eval/files/G1-paragraph--*.IZ4`)
- C: the five-field card (`eval/files/G3-five-field-binds--*.IZ4`)

Rotate the order per reader (ABC, BCA, CAB). Give no explanation of the
format. Say only: "This file belongs to a software project. Read it as you
would before changing the software."

## Tasks, timed

For each version, time from first sight to answer.

1. First glance (30 seconds, then take the file away): what is this file for?
2. Find the promise about sign-in codes. When does it apply?
3. What must always be true about it?
4. Who or what does it protect?
5. May a developer change its wording without asking anyone? How do you know?
6. If a test for it fails, does the change go in?
7. Does the file tell you whether that promise is currently kept?
8. Find a promise whose wording is still free to change. May the developer
   write code that breaks it, without telling anyone?
9. Which of the fifteen promises can nobody in this project change?
10. Point to the line that told you the answer to 5 and to 6.

## After all three

- Rank the three for: easiest to read; easiest to skim for one promise;
  the one you would rather edit in a terminal.
- Does "ALWAYS" read better than "MUST" would? Show the line both ways.
- In C, does the shift from the first three lines to CHANGE BY and CHECK BY
  feel natural or like a different document?
- In C, does the FOUNDATION heading help, or would PROMISE do?
- Which version is longer than you want to read before every change?
- One thing you would change in your preferred version.

## Record

Per reader, per version: time per task, answer, right or wrong against the
key below, the line they pointed to, and their words. Do not prompt.

## Key

- Sign-in code: applies when a code is submitted; works at most once before
  expiry, including concurrent submissions; protects accounts; wording needs
  a signed approval; a failing test holds the change; the file never says
  whether it is kept.
- Task 8: no. Free wording is permission to edit the words, not to break the
  promise.
- Task 9: the five names under iz4.you.

## What would count

A format is better for people if it is faster on tasks 2 to 10 with no more
wrong answers, is ranked easiest by most readers, and its length is not named
as a cost by most readers. Report counts and times, not impressions.
