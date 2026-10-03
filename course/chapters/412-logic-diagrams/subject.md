---
title: Logic diagrams (integration test)
---

Integration test of the `<logic-diagram>` element from Companion Gate in a
subject page, and in the slides above it.

<!-- more -->

## Defaults

The relay AND gate with no attribute but its name: it follows the page's theme
(the reader's system preference), plays on load and has the minimal control bar
(reset only).

<logic-diagram name="relay-and"></logic-diagram>

- [ ] Clicking switch A, then B, lights the lamp once the relays have closed.
- [ ] Tab reaches each switch, and Enter or Space toggles it without scrolling
      the page.
- [ ] Reset returns both switches to off.
- [ ] Switching the system to dark mode turns both the page and the diagram
      dark.

## Initial inputs

The same diagram starting with both switches closed:

<logic-diagram name="relay-and" inputs="A=1, B=1,"></logic-diagram>

- [ ] The lamp is lit on load, without the relays visibly closing.
- [ ] Reset returns to both switches closed, not to off.

## Full controls, speed and autoplay

The SR latch, paused until played, at slow speed, with the full control bar:

<logic-diagram name="sr-latch" inputs="S=1" controls="full" speed="slow" autoplay="false"></logic-diagram>

- [ ] Nothing moves until play is pressed.
- [ ] Next change advances to the next change and stops.
- [ ] The speed menu changes the speed; `instant` jumps to the settled state.
- [ ] Toggling S and R while paused does not animate until play or next change.

## No controls

The half adder without a control bar. Its inputs are still clickable:

<logic-diagram name="half-adder" controls="none"></logic-diagram>

- [ ] No control bar is shown.
- [ ] Clicking A and B updates the sum and the carry.

## Clocked diagram

The 3-bit counter: a clock defaults to the full control bar.

<logic-diagram name="counter" speed="fast"></logic-diagram>

- [ ] The full control bar is shown without asking for it.
- [ ] Pause stops the count; play resumes it.
- [ ] Scrolling it out of view and back does not leave it counting off screen
      (its count should not have jumped).

## Forced themes

The decoder forced to the light theme, then to the dark one, whatever the
system preference:

<logic-diagram name="decoder" theme="light"></logic-diagram>

<logic-diagram name="decoder" theme="dark"></logic-diagram>

- [ ] In both system modes, the first is light and the second dark.

## Debug overlay

<logic-diagram name="relay-single" debug></logic-diagram>

- [ ] The grid, pins and cursor coordinates are shown.

## Authoring mistakes

An unknown name, then an input the diagram does not have, and a value that is
not `0` or `1`:

<logic-diagram name="relay-nand"></logic-diagram>

<logic-diagram name="relay-and" inputs="C=1"></logic-diagram>

<logic-diagram name="relay-and" inputs="A=2"></logic-diagram>

- [ ] Each shows its problem in place of the diagram.

Invalid `controls`, `speed`, `autoplay` and `theme` values fall back to their
defaults:

<logic-diagram name="relay-or" controls="lots" speed="ludicrous" autoplay="maybe" theme="sepia"></logic-diagram>

- [ ] It plays, with the minimal control bar, at normal speed, in the page's
      theme.

## Print

Print this page from the browser, in both system modes.

- [ ] Every diagram is printed, without its control bar.
- [ ] The diagrams show their settled state, with no half-closed relay.
- [ ] Diagrams following the system theme are printed light, not dark on paper.
- [ ] No diagram is split across two pages.
