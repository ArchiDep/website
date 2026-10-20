// A diagram turning into another, drawn in a file of its own, such as a slide
// handing over to the next one, over as many steps as it takes. At each step,
// parts of this drawing fade out, take a new shape, or move to where the other
// drawing draws them, and parts of the other fade in once the rest is in place.
// The last step ends on the other drawing as stepping through it starts, so
// that cutting to it shows no change, which is checked once every step is
// built: every part either drawing shows by then must have left, moved into the
// other's place, or arrived from it, itself or by a group around it.
//
// Parts both drawings have share an id. What a class draws and a move changes,
// such as a frame's dashes turning solid, is written as an inline style on both
// drawings, so that the move can go from one to the other. The next slide is
// marked `data-transition="none"`, so that the cut does not show.
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

// When each part of a step happens, from its start: what leaves fades out as
// the rest starts moving, and what arrives fades in once the rest is in place.
const MOVE_DELAY = 0.3;
const MOVE = 0.9;

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

/**
 * The new values of a part's attributes, by its id.
 */
export type Shapes = Readonly<Record<string, Readonly<Record<string, string>>>>;

export interface Becoming {
  /**
   * Parts of this drawing that fade out at this step.
   */
  leaving(...ids: string[]): Action;
  /**
   * Parts of this drawing that take new values at this step, on the way. The
   * `unseen` ones fade out as they start moving, and back in once in place.
   */
  reshaped(
    shapes: Shapes,
    options?: { readonly unseen?: readonly string[] }
  ): Action;
  /**
   * Parts both drawings have that move to where the other draws them, and take
   * its shape: a group by as much as its first box.
   */
  into(...ids: string[]): Action;
  /**
   * Parts only the other drawing has, copied in, that fade in once the rest is
   * in place: over everything, or just under the part named `under`.
   */
  arriving(
    ids: readonly string[],
    options?: { readonly under?: string }
  ): Action;
}

/**
 * A drawing of the diagrams' directory, read as a diagram becomes it.
 */
export function drawingOf(file: string): Document {
  return parseSvg(readFileSync(file, 'utf8'), file);
}

interface Step {
  moves: boolean;
  leaves: boolean;
  readonly arrivals: Element[];
}

interface State {
  /**
   * Each part's attributes as the steps built so far leave them, by its id.
   */
  readonly latest: Map<string, Map<string, string>>;
  /**
   * The step each part last changed at, and the step it last moved into the
   * other drawing at.
   */
  readonly changed: Map<string, number>;
  readonly moved: Map<string, number>;
  readonly left: Set<string>;
  readonly arrived: Set<string>;
  readonly steps: Map<number, Step>;
}

/**
 * The steps through which this diagram becomes `other`.
 */
export function becoming(other: Document): Becoming {
  const key = Symbol('becoming');
  const stateOf = (builder: Builder): State =>
    builder.state<State>(key, () => {
      const state: State = {
        latest: new Map(),
        changed: new Map(),
        moved: new Map(),
        left: new Set(),
        arrived: new Set(),
        steps: new Map()
      };
      builder.whenBuilt(() => finish(builder, other, state));
      return state;
    });

  return {
    leaving:
      (...ids) =>
      (builder, index) => {
        const state = stateOf(builder);
        stepOf(state, index).leaves = true;
        ids.forEach(id => state.left.add(id));
        teardown(ids)(builder, index);
      },

    reshaped:
      (shapes, { unseen = [] } = {}) =>
      (builder, index) => {
        const state = stateOf(builder);
        for (const [id, attributes] of Object.entries(shapes)) {
          for (const [attribute, value] of Object.entries(attributes)) {
            change(builder, state, index, id, attribute, value);
          }
        }

        for (const id of unseen) {
          const element = builder.element(id);
          const at = element.getAttribute('data-unseen-at');
          element.setAttribute(
            'data-unseen-at',
            at ? `${at} ${index}` : String(index)
          );
        }
      },

    into:
      (...ids) =>
      (builder, index) => {
        const state = stateOf(builder);
        for (const id of ids) {
          for (const [attribute, value] of Object.entries(
            targetOf(builder.drawing, other, id)
          )) {
            change(builder, state, index, id, attribute, value);
          }

          state.moved.set(id, index);
          // Its last change, even if it is already in place.
          state.changed.set(id, index);
        }
      },

    arriving:
      (ids, { under } = {}) =>
      (builder, index) => {
        const state = stateOf(builder);
        for (const id of ids) {
          state.arrived.add(id);
          const copy = copyOf(
            builder.doc.importNode(byId(other, id), true) as Element
          );
          builder.copied(id, copy);
          reveal(copy, index, 'transient', 'arrive');
          stepOf(state, index).arrivals.push(copy);
          if (under === undefined) {
            builder.overlays.push(copy);
          } else {
            const reference = builder.element(under);
            reference.parentNode?.insertBefore(copy, reference);
          }
        }
      }
  };
}

function stepOf(state: State, index: number): Step {
  const step = state.steps.get(index) ?? {
    moves: false,
    leaves: false,
    arrivals: []
  };
  state.steps.set(index, step);
  return step;
}

/**
 * Gives a part a new value for an attribute from the step at `index`, as a
 * `data-reshaped-<index>-<attribute>` attribute, which the motion script moves
 * it to.
 */
function change(
  builder: Builder,
  state: State,
  index: number,
  id: string,
  attribute: string,
  value: string
): void {
  const element = builder.element(id);
  const values = state.latest.get(id) ?? new Map<string, string>();
  state.latest.set(id, values);
  let from = values.get(attribute) ?? element.getAttribute(attribute);
  if (from === null && attribute === 'transform') {
    // A group moves from where it is drawn.
    from = 'translate(0 0)';
    element.setAttribute('transform', from);
  }

  if (from === null) {
    throw new Error(`"${id}" has no "${attribute}" to change`);
  }

  if (from === value) {
    return;
  }

  values.set(attribute, value);
  state.changed.set(id, index);
  stepOf(state, index).moves = true;
  element.setAttribute(`data-reshaped-${index}-${attribute}`, value);
}

/**
 * The attributes a part takes in the other drawing, by its kind.
 */
function targetOf(
  drawing: Document,
  other: Document,
  id: string
): Record<string, string> {
  const element = byId(drawing, id);
  const target = byId(other, id);
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
    return {
      transform: `translate(${number(to, 'x') - number(from, 'x')} ${number(to, 'y') - number(from, 'y')})`
    };
  }

  const attributes = SHAPED[element.localName ?? ''];
  if (attributes === undefined) {
    throw new Error(`"${id}" is a <${element.localName}>, which cannot move`);
  }

  // A text moves, but does not change what it says: one that does must leave,
  // and the other's arrive.
  if (
    element.localName === 'text' &&
    element.textContent !== target.textContent
  ) {
    throw new Error(
      `"${id}" reads "${element.textContent}" here and "${target.textContent}" in the drawing it becomes`
    );
  }

  const values: Record<string, string> = {};
  for (const attribute of attributes) {
    const to = target.getAttribute(attribute);
    if ((element.getAttribute(attribute) === null) !== (to === null)) {
      throw new Error(
        `"${id}" has a "${attribute}" in only one of the two drawings`
      );
    }

    if (to !== null) {
      values[attribute] = to;
    }
  }

  return values;
}

function firstBox(group: Element, id: string): Element {
  const rect = firstDescendant(group, 'rect');
  if (rect === undefined) {
    throw new Error(`"${id}" is a group moved, and has no box to move it by`);
  }

  return rect;
}

/**
 * Times each step, and checks that the last one ends on the other drawing.
 */
function finish(builder: Builder, other: Document, state: State): void {
  for (const [index, step] of state.steps) {
    const delay = step.leaves ? MOVE_DELAY : 0;
    if (step.moves) {
      setVariables(builder.mark('reshape', index), {
        delay: seconds(delay),
        duration: seconds(MOVE)
      });
    }

    for (const arrival of step.arrivals) {
      setVariables(arrival, {
        delay: seconds(delay + (step.moves ? MOVE : 0))
      });
    }
  }

  for (const [id, index] of state.moved) {
    if (state.changed.get(id) !== index) {
      throw new Error(
        `${builder.name}.svg: "${id}" changes after it moves into the drawing it becomes`
      );
    }
  }

  const moved = [...state.moved.keys()];
  check(builder, builder.drawing, [...moved, ...state.left], 'at its end');
  check(builder, other, [...moved, ...state.arrived], 'as the other starts');
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

    // A group with nothing in it draws nothing, such as a layer that steps
    // draw into.
    const children = childElements(element);
    return children.length > 0
      ? children.every(accounted)
      : element.localName === 'g';
  };

  for (const element of childElements(rootOf(doc))) {
    const missing = unaccounted(element, accounted);
    if (missing !== undefined) {
      const id = missing.getAttribute('id');
      const part = id
        ? `<${missing.localName}> "${id}"`
        : `<${missing.localName}>`;
      throw new Error(
        `${builder.name}.svg: a ${part} shown ${when} has neither left, moved nor arrived`
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
