---
title: Logic diagrams (integration test)
---

# {{ page.title }}

Architecture & Deployment <!-- .element: class="subtitle" -->

---

## Default theme on a light deck

No `theme` attribute: does it stay light when the system is dark?

<logic-diagram name="relay-and" style="width: 320px; margin: 0 auto">
</logic-diagram>

**Notes:**

The deck is always light. With the system in dark mode, check whether this
diagram turns dark on the light slide.

---

## Keys on a toggle

<logic-diagram name="relay-and" theme="light" style="width: 420px; margin: 0 auto">
</logic-diagram>

**Notes:**

Tab to switch A. Enter and Space toggle it and do not advance the deck. The
arrow keys still change slides.

---

## Keys in the control bar

<logic-diagram name="sr-latch" controls="full" autoplay="false" theme="light" style="width: 640px; margin: 0 auto">
</logic-diagram>

**Notes:**

Space or Enter on play, next change or reset does not advance the deck. The
arrow keys in the speed menu change the speed, not the slide.

---

## Fragments on the same slide

<logic-diagram name="half-adder" theme="light" style="width: 560px; margin: 0 auto">
</logic-diagram>

- Sum is A XOR B <!-- .element: class="fragment" -->
- Carry is A AND B <!-- .element: class="fragment" -->

**Notes:**

With a switch focused, Space toggles it and does not show the next fragment.
Without focus, Space shows the fragments as usual.

---

## Clock on a slide

<logic-diagram name="counter" theme="light">
</logic-diagram>

**Notes:**

Leave this slide and come back after a while: the counter should not have kept
counting while off screen. The next and previous slides stay out of the Tab
order.

--v

## Vertical slide below a clock

<logic-diagram name="d-flip-flop-block" inputs="D=1" theme="light">
</logic-diagram>

**Notes:**

Coming down from the counter: Tab only reaches this slide's toggles, and the
deck never scrolls to a blank slide.

---

## Big diagram on a scaled slide

<logic-diagram name="full-adder" theme="light">
</logic-diagram>

**Notes:**

Resize the window small: clicks on a scaled slide hit the right inputs. Check
the label size, and that the control bar stays inside the slide.

---

## Two diagrams side by side

<div class="grid grid-cols-2 gap-8">
<logic-diagram name="relay-or" theme="light">
</logic-diagram>
<logic-diagram name="relay-not" theme="light">
</logic-diagram>
</div>

**Notes:**

Both are clickable and independent. In print, both fit on the slide.
