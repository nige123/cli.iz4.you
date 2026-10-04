# IZ4 Conformance

Version 1.0 · `iz4-conformance/1.0`

IZ4 keeps a tiny core, and so does this page. It says when a project may
present itself as a conforming IZ4 project. If you can read an IZ4 file,
you can check every point below in a couple of minutes.

The one thing that cannot move: **the official IZ4 Foundation stays
intact.**

## A project conforms when

1. **It has an IZ4.** A file named `IZ4` at the root of the project, in
   the IZ4 format (`iz4 check` passes its structure).
2. **It carries the Foundation word for word.** Invariants 0 to 4, exactly
   as published. Their SHA-256 digest identifies the version; Foundation
   `9782949420dc1941338b7287e992ed20559447190e4342f94be53ff0bbad560a` is
   current. `iz4 check` reports whether the file carries it.
3. **Nothing overrides the Foundation.** The project's own invariants
   begin at 5. None of them may weaken, override or contradict 0 to 4.
4. **It names what it conforms to.** Where it claims conformance, it names
   this Conformance version and the Foundation digest.
5. **Its claims are true.** It only claims conformance, and only shows the
   IZ4 badge, while points 1 to 4 hold for the version it is shown on.

## The badge

A registered project shows the IZ4 badge only when, in addition:

- it is registered on iz4.you under the IZ4 Trademark Licence, and that
  licence is active, and
- its evidence on the register shows the declaration present with a
  passing syntax check.

## When a project stops conforming

If you know a version no longer conforms, stop presenting it as IZ4 and
stop showing the badge for it, and fix it or give it its own identity.
Changing the Foundation is allowed: the result is simply no longer IZ4.

## What conformance is not

Conformance is about the file, not the behaviour. A checker can confirm
that the Foundation is present and intact; it cannot confirm that the
software keeps it. Conformance is self-declared, and nobody audits it.
It is not a certification, and it says nothing about safety, security or
quality beyond what the file states.
