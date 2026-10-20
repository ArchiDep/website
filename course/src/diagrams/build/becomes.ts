// A diagram turning into another, drawn in a file of its own, such as a slide
// handing over to the next one: the parts both drawings have move to where the
// other draws them, the parts only this one has fade out, and the parts only
// the other has fade in. The step ends on the other drawing as it starts, so
// that cutting to it shows no change.
import { readFileSync } from 'node:fs';

import type { Document, Element } from '@xmldom/xmldom';

import { copyOf, reveal, teardown } from './actions';
import type { Action, Builder } from './builder';
import {
  byId,
  childElements,
  classesOf,
  firstDescendant,
  number,
  parseSvg,
  rootOf,
  setVariables
} from './svg';
import { seconds } from './timing';

// When each part of the change happens, from the start of the step: what leaves
// fades out as the rest starts moving, and what arrives fades in once the rest
// is in place.
const MOVE_DELAY = 0.3;
const MOVE = 0.9;
const ARRIVE_DELAY = MOVE_DELAY + MOVE;

/**
 * What a shape's place and look are made of, by its kind: what a part moved
 * into the other drawing takes from it. A group is moved as a whole.
 */
const SHAPED: Readonly<Record<string, readonly string[]>> = {
  rect: ['x', 'y', 'width', 'height', 'rx', 'style'],
  path: ['d', 'style'],
  polygon: ['points', 'style'],
  text: ['x', 'y', 'transform']
};

// What draws nothing of its own.
const UNDRAWN = new Set(['title', 'desc', 'style', 'defs', 'clipPath']);

export interface Becoming {
  /**
   * Parts both drawings have, by the same id: each moves to where the other
   * draws it, and takes its shape.
   */
  readonly moved: readonly string[];
  /**
   * Parts only this drawing has: they fade out.
   */
  readonly leaving: readonly string[];
  /**
   * Parts only the other drawing has: copied in, they fade in once the others
   * are in place.
   */
  readonly arriving: readonly string[];
}

/**
 * A drawing of the diagrams' directory, read as a step turns into it.
 */
export function drawingOf(file: string): Document {
  return parseSvg(readFileSync(file, 'utf8'), file);
}

/**
 * This step turns the diagram into `other`, as it shows when stepping through
 * it starts. Every part either drawing shows by then must be moved, leaving or
 * arriving, or inside one that is: a part left out would appear or disappear
 * when cutting from one to the other.
 */
export function becomes(
  other: Document,
  { moved, leaving, arriving }: Becoming
): Action {
  return (builder, index) => {
    check(builder, builder.drawing, [...moved, ...leaving], 'at its end');
    check(builder, other, [...moved, ...arriving], 'as the other starts');

    const marker = builder.mark('reshape', index);
    setVariables(marker, {
      delay: seconds(MOVE_DELAY),
      duration: seconds(MOVE)
    });

    for (const id of moved) {
      reshape(builder.element(id), byId(other, id), id);
    }

    teardown(leaving)(builder, index);

    for (const id of arriving) {
      const copy = copyOf(
        builder.doc.importNode(byId(other, id), true) as Element
      );
      reveal(copy, index, 'transient', 'arrive');
      setVariables(copy, { delay: seconds(ARRIVE_DELAY) });
      builder.overlays.push(copy);
    }
  };
}

/**
 * Gives a part what it becomes as `data-reshaped-<attribute>` attributes, which
 * the motion script moves it to: a shape takes the other's place and shape, a
 * group is moved by as much as its first box is.
 */
function reshape(element: Element, target: Element, id: string): void {
  if (element.localName !== target.localName) {
    throw new Error(
      `"${id}" is a <${element.localName}> here and a <${target.localName}> in the drawing it becomes`
    );
  }

  if (element.localName === 'g') {
    if (element.hasAttribute('transform')) {
      throw new Error(`"${id}" is a group moved, and has a transform already`);
    }

    const from = firstBox(element, id);
    const to = firstBox(target, id);
    element.setAttribute('transform', 'translate(0 0)');
    element.setAttribute(
      'data-reshaped-transform',
      `translate(${number(to, 'x') - number(from, 'x')} ${number(to, 'y') - number(from, 'y')})`
    );
    return;
  }

  const attributes = SHAPED[element.localName ?? ''];
  if (attributes === undefined) {
    throw new Error(`"${id}" is a <${element.localName}>, which cannot move`);
  }

  for (const attribute of attributes) {
    const from = element.getAttribute(attribute);
    const to = target.getAttribute(attribute);
    if (from === to) {
      continue;
    }

    if (from === null || to === null) {
      throw new Error(
        `"${id}" has a "${attribute}" in only one of the two drawings`
      );
    }

    element.setAttribute(`data-reshaped-${attribute}`, to);
  }
}

function firstBox(group: Element, id: string): Element {
  const rect = firstDescendant(group, 'rect');
  if (rect === undefined) {
    throw new Error(`"${id}" is a group moved, and has no box to move it by`);
  }

  return rect;
}

/**
 * Throws on a part of a drawing shown while stepping through it that none of
 * the ids accounts for, itself or by a group around it or all of its parts.
 */
function check(
  builder: Builder,
  doc: Document,
  ids: readonly string[],
  when: string
): void {
  const named = new Set(ids);
  const accounted = (element: Element): boolean => {
    if (
      named.has(element.getAttribute('id') ?? '') ||
      UNDRAWN.has(element.localName ?? '') ||
      classesOf(element).some(c => c === 'at-rest' || c === 'transient')
    ) {
      return true;
    }

    const children = childElements(element);
    return children.length > 0 && children.every(accounted);
  };

  for (const element of childElements(rootOf(doc))) {
    const missing = unaccounted(element, accounted);
    if (missing !== undefined) {
      throw new Error(
        `${builder.name}.svg: a <${missing.localName}>${missing.getAttribute('id') ? ` "${missing.getAttribute('id')}"` : ''} shown ${when} is neither moved, leaving nor arriving`
      );
    }
  }
}

function unaccounted(
  element: Element,
  accounted: (element: Element) => boolean
): Element | undefined {
  if (accounted(element)) {
    return undefined;
  }

  const children = childElements(element);
  if (children.length === 0) {
    return element;
  }

  for (const child of children) {
    const missing = unaccounted(child, accounted);
    if (missing !== undefined) {
      return missing;
    }
  }

  return element;
}
