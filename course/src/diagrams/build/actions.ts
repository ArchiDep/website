// What a step can do in any diagram, whatever its family. Each action names the
// elements it concerns by their ids in the drawing, and adds to them what the
// motion stylesheet and script need: the `fragment` class reveal.js and the
// page stepper key off, the index of the step, and the timings of its motion
// as custom properties. A family's own actions are built on these.
import type { Element } from '@xmldom/xmldom';

import { START, type Action, type Builder } from './builder';
import { addClasses, descendants, removeClasses, setVariables } from './svg';
import { seconds } from './timing';

/**
 * Makes an element a step of its own: hidden until the step at `index` is
 * reached, with the classes that say how it appears.
 */
export function reveal(
  element: Element,
  index: number,
  ...classes: string[]
): void {
  addClasses(element, 'fragment', ...classes);
  element.setAttribute('data-fragment-index', String(index));
}

/**
 * Appears as it is.
 */
export function show(...ids: string[]): Action {
  return (builder, index) => {
    for (const id of ids) {
      reveal(builder.element(id), index);
    }
  };
}

/**
 * What goes away at this step, such as a session closing. The fully drawn
 * diagram still shows it. With `after`, it waits for what takes it away to
 * arrive, such as a keystroke.
 */
export function teardown(
  ids: readonly string[],
  { after = 0 }: { readonly after?: number } = {}
): Action {
  return (builder, index) => {
    builder.mark('teardown', index);
    for (const id of ids) {
      goneFrom(builder.element(id), index, after);
    }
  };
}

/**
 * Marks an element gone from the step at `index`, `after` seconds into it. The
 * step must be marked as a teardown, once however many elements go.
 */
export function goneFrom(element: Element, index: number, after = 0): void {
  element.setAttribute('data-gone-from', String(index));
  if (after) {
    setVariables(element, { 'gone-delay': seconds(after) });
  }
}

/**
 * A stretch of consecutive steps: from the step at `from` until the step at
 * `to`, which it is no longer shown at, or to the end without one.
 */
export interface Run {
  readonly from: number;
  readonly to?: number;
}

/**
 * The stretches of consecutive steps among the indices of steps, in order: the
 * steps at 1, 2 and 5 are one stretch from 1 until 3, and another from 5 until
 * 6. A stretch reaching the last step goes on to the end.
 */
export function runs(indices: Iterable<number>, steps: number): Run[] {
  const sorted = [...new Set(indices)].sort((a, b) => a - b);
  const found: Run[] = [];
  let from: number | undefined;
  sorted.forEach((index, i) => {
    from ??= index;
    const next = sorted[i + 1];
    if (next !== index + 1) {
      found.push(index + 1 < steps ? { from, to: index + 1 } : { from });
      from = undefined;
    }
  });

  return found;
}

const TEARDOWNS = Symbol('teardowns');

/**
 * Shows an element only during a stretch of steps: from the step at `from`, or
 * from the start of stepping if it is `START`, until the step at `to`, or to
 * the end without one. The fully drawn diagram leaves it out, unless it is
 * shown from the start and `atRest` says the fully drawn diagram shows it too.
 * Each time an element of the drawing is shown again, it is a copy of it shown.
 */
export function during(
  builder: Builder,
  element: Element,
  { from, to }: Run,
  { atRest = false }: { readonly atRest?: boolean } = {}
): void {
  if (from === START) {
    // Shown before any step is reached, which a transient element is not.
    removeClasses(element, 'transient');
    if (!atRest) {
      addClasses(element, 'detail');
    }
  } else {
    reveal(element, from, 'transient');
  }

  if (to !== undefined) {
    const marked = builder.state(TEARDOWNS, () => new Set<number>());
    if (!marked.has(to)) {
      marked.add(to);
      builder.mark('teardown', to);
    }

    goneFrom(element, to);
  }
}

/**
 * A copy of an element of the drawing, without the ids that would make it a
 * second element of the same name.
 */
export function copyOf(element: Element): Element {
  const copy = element.cloneNode(true) as Element;
  for (const each of [copy, ...descendants(copy)]) {
    each.removeAttribute('id');
  }

  return copy;
}
