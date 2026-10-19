// What a step can do in any diagram, whatever its family. Each action names the
// elements it concerns by their ids in the drawing, and adds to them what the
// motion stylesheet and script need: the `fragment` class reveal.js and the
// page stepper key off, the index of the step, and the timings of its motion
// as custom properties. A family's own actions are built on these.
import type { Element } from '@xmldom/xmldom';

import type { Action } from './builder';
import { addClasses, setVariables } from './svg';
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
