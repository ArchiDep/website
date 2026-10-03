---
title: Hello logic diagrams (integration test)
---

Integration test of the `<logic-diagram>` element from Companion Gate in an
exercise page.

<!-- more -->

## Predict, then check

**Predict:** with switch A closed and switch B open, is the lamp lit? Then
toggle the switches to check your prediction:

<logic-diagram name="relay-and" inputs="A=1"></logic-diagram>

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

No: both relays must be closed for current to reach the lamp.

<logic-diagram name="relay-and" inputs="A=1, B=1" controls="none"></logic-diagram>

{% endsolution %}

- [ ] The diagram plays and toggles as in the subject page.
- [ ] The diagram inside the solution renders when the solution is opened, at
      the right size, and its switches toggle.

## Step through a latch

<logic-diagram name="d-latch" controls="full" autoplay="false" speed="slow"></logic-diagram>

- [ ] Play, next change, the speed menu and reset all work.
- [ ] Keyboard shortcuts of the page (such as the search dialog's) still work
      with a switch focused.

## Print

Print this page from the browser, with the solution closed and open.

- [ ] Every diagram is printed, without its control bar, in its settled state.
- [ ] The diagram in the solution is printed as the solution itself is.
