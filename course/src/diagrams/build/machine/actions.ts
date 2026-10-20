// What a step can do in a machine diagram. A step says what holds while it is
// the current one — what is lit, which wires are live, what each register
// holds, what it is about — and the vocabulary works out, once every step is
// known, how long each thing lasts: one copy of a lit cell for each stretch of
// steps it stays lit, one text for each value a register holds.
//
// The fully drawn diagram is the machine as its program starts, which a reader
// can trace the program from: the drawing, with what the machine holds from the
// start of stepping.
import type { Element } from '@xmldom/xmldom';

import { copyOf, during, reveal, runs, type Run } from '../actions';
import { START, type Action, type Builder } from '../builder';
import {
  addClasses,
  childElements,
  create,
  descendants,
  firstDescendant,
  hasClass,
  insertAfter,
  number,
  setVariables
} from '../svg';
import { seconds } from '../timing';

// How long each cell stays lit as the highlight walks through them.
const WALK = 0.16;

/**
 * A value a register or a decoded field holds, or nothing.
 */
export type Value = number | string | null;

interface Change {
  readonly index: number;
  readonly value: Value;
}

/**
 * What the steps of a machine diagram say, while it is built.
 */
interface Machine {
  /**
   * The steps each element is lit at, by its id.
   */
  readonly lit: Map<string, number[]>;
  /**
   * The steps the memory is read or written at.
   */
  readonly access: Record<'read' | 'write', number[]>;
  /**
   * The steps each live wire is live at, by its path.
   */
  readonly live: Map<string, number[]>;
  /**
   * The values each slot takes, in the order of the steps.
   */
  readonly values: Map<string, Change[]>;
  /**
   * The steps the clock ticks at.
   */
  readonly ticks: Set<number>;
  /**
   * The steps the processor works at.
   */
  readonly works: number[];
  /**
   * What the highlight walks through at each step that has it walk, in order.
   */
  readonly walks: Map<number, readonly string[]>;
  /**
   * The parts that can be faded, and what each step is about.
   */
  focus: {
    readonly parts: readonly string[];
    readonly focused: Map<number, ReadonlySet<string>>;
  } | null;
}

const MACHINE = Symbol('machine');

function machine(builder: Builder): Machine {
  return builder.state<Machine>(MACHINE, () => {
    const state: Machine = {
      lit: new Map(),
      access: { read: [], write: [] },
      live: new Map(),
      values: new Map(),
      ticks: new Set(),
      works: [],
      walks: new Map(),
      focus: null
    };
    builder.whenBuilt(() => draw(builder, state));
    return state;
  });
}

function record<K>(map: Map<K, number[]>, key: K, index: number): void {
  const indices = map.get(key) ?? [];
  indices.push(index);
  map.set(key, indices);
}

/**
 * Lit while this step is the current one: a pill of the cycle or the memory
 * cell being read or written, like a lamp, or a control signal the control
 * unit gives. What is lit is the element if it is a shape, such as a wire, or
 * else its first shape.
 */
export function lit(...ids: string[]): Action {
  return (builder, index) => {
    for (const id of ids) {
      record(machine(builder).lit, id, index);
    }
  };
}

/**
 * The memory is read while this step is the current one: the R of its R/W
 * controls, the drawing's `read-write` text, is lit.
 */
export function reads(): Action {
  return (builder, index) => {
    machine(builder).access.read.push(index);
  };
}

/**
 * The memory is written while this step is the current one: the W of its R/W
 * controls, the drawing's `read-write` text, is lit.
 */
export function writes(): Action {
  return (builder, index) => {
    machine(builder).access.write.push(index);
  };
}

/**
 * A connection the control signals open while this step is the current one,
 * drawn like a live wire in the circuits along a path of the drawing's
 * coordinates, in its `live-wires` group, over everything else.
 */
export function live(path: string): Action {
  return (builder, index) => {
    record(machine(builder).live, path, index);
  };
}

/**
 * From this step on, a slot holds a value, until another step gives it
 * another, or nothing. A register's slot is its group, whose `bit` boxes show
 * the value in binary, its decimal value shown by a copy of `decimal-<slot>` if
 * the drawing has one. A template drawn `transient`, such as a decoded field,
 * is copied with the value as its text. Any other slot is a text the drawing
 * shows, such as a cell's bits, which is what it holds from the start: it is
 * shown until a step gives it a value, each copied with the value as its text.
 *
 * Given at the start, the value is shown in the fully drawn diagram too. A
 * text the drawing shows must hold it already.
 */
export function value(slot: string, held: Value): Action {
  return (builder, index) => {
    const values = machine(builder).values;
    const changes = values.get(slot) ?? [];
    changes.push({ index, value: held });
    values.set(slot, changes);
  };
}

/**
 * The clock ticks as this step starts: the drawing's `clock-wave` and the
 * first wire of `wire-clock` are lit for the step, flashing as it starts. Each
 * step's tick is drawn on its own, so that ticks on consecutive steps each
 * flash.
 */
export function tick(): Action {
  return (builder, index) => {
    machine(builder).ticks.add(index);
  };
}

/**
 * The processor works while this step is the current one: a copy of the
 * drawing's `cog` turns, without stopping between consecutive steps.
 */
export function works(): Action {
  return (builder, index) => {
    machine(builder).works.push(index);
  };
}

/**
 * The highlight walks through cells within this step, each lit in turn for a
 * moment, such as a program run from its first instruction to its last
 * without a jump. The last one stays lit until the next step.
 */
export function walks(...ids: string[]): Action {
  return (builder, index) => {
    machine(builder).walks.set(index, ids);
  };
}

/**
 * Shown from this step on, filling from the bottom, such as a band of memory
 * a program is copied into: its first shape grows, then the rest appears.
 */
export function fills(id: string): Action {
  return (builder, index) => {
    reveal(builder.element(id), index, 'fill');
  };
}

/**
 * What a step is about, among the parts of the drawing that can be faded: the
 * others are faded while the step is the current one. A step that says nothing
 * of it fades nothing.
 */
export function focusOn(
  parts: readonly string[]
): (...focused: string[]) => Action {
  return (...focused) =>
    (builder, index) => {
      const state = machine(builder);
      state.focus ??= { parts, focused: new Map() };
      if (state.focus.parts !== parts) {
        throw new Error(
          `${builder.name}.svg: focus is given on two different sets of parts`
        );
      }

      for (const id of focused) {
        if (!parts.includes(id)) {
          throw new Error(
            `${builder.name}.svg: "${id}" is not one of the parts focus is given on`
          );
        }
      }

      state.focus.focused.set(index, new Set(focused));
      builder.mark('focus', index);
    };
}

function draw(builder: Builder, state: Machine): void {
  for (const [id, indices] of state.lit) {
    drawLit(builder, id, indices);
  }

  drawAccess(builder, 'read', state.access.read);
  drawAccess(builder, 'write', state.access.write);

  for (const [path, indices] of state.live) {
    drawLive(builder, path, indices);
  }

  for (const [slot, changes] of state.values) {
    drawValues(builder, slot, changes);
  }

  for (const index of state.ticks) {
    drawTick(builder, index);
  }

  for (const run of runs(state.works, builder.steps)) {
    const cog = builder.element('cog');
    const copy = copyOf(cog);
    insertAfter(cog, copy);
    during(builder, copy, run);
  }

  for (const [index, ids] of state.walks) {
    drawWalk(builder, index, ids);
  }

  if (state.focus !== null) {
    drawFocus(builder, state.focus.parts, state.focus.focused);
  }
}

/**
 * What lighting an element lights: the element if it is a shape, such as a
 * wire, or else its first shape.
 */
function shapeOf(builder: Builder, id: string): Element {
  const element = builder.element(id);
  const isShape = (candidate: Element): boolean =>
    ['rect', 'polygon', 'path'].includes(candidate.localName ?? '');
  const shape = isShape(element)
    ? element
    : childElements(element).find(isShape);
  if (shape === undefined) {
    throw new Error(`"${id}" has no shape to light`);
  }

  return shape;
}

function drawLit(builder: Builder, id: string, indices: number[]): void {
  const shape = shapeOf(builder, id);
  for (const run of runs(indices, builder.steps)) {
    const copy = copyOf(shape);
    addClasses(copy, 'lit');
    insertAfter(shape, copy);
    during(builder, copy, run);
  }
}

function drawTick(builder: Builder, index: number): void {
  const run: Run =
    index + 1 < builder.steps
      ? { from: index, to: index + 1 }
      : { from: index };
  for (const id of ['clock-wave', 'wire-clock']) {
    const shape = shapeOf(builder, id);
    const copy = copyOf(shape);
    addClasses(copy, 'lit', 'tick');
    insertAfter(shape, copy);
    during(builder, copy, run);
  }
}

/**
 * A lit copy of each cell, for the step, each timed to be lit after the one
 * before, the last one from then on.
 */
function drawWalk(builder: Builder, index: number, ids: readonly string[]) {
  const run: Run =
    index + 1 < builder.steps
      ? { from: index, to: index + 1 }
      : { from: index };
  ids.forEach((id, i) => {
    const shape = shapeOf(builder, id);
    const copy = copyOf(shape);
    addClasses(copy, 'lit', 'walk', ...(i === ids.length - 1 ? ['last'] : []));
    setVariables(copy, {
      delay: seconds(i * WALK),
      each: seconds(WALK)
    });
    insertAfter(shape, copy);
    during(builder, copy, run);
  });
}

/**
 * R or W lit, by a copy of the R/W controls over them, the other letters
 * drawn `unlit`, so that the lit one sits exactly where the font puts it.
 */
function drawAccess(
  builder: Builder,
  access: 'read' | 'write',
  indices: number[]
): void {
  if (indices.length === 0) {
    return;
  }

  const controls = builder.element('read-write');
  for (const run of runs(indices, builder.steps)) {
    const copy = copyOf(controls);
    while (copy.firstChild !== null) {
      copy.removeChild(copy.firstChild);
    }

    const unlit = (text: string): Element =>
      create(builder.doc, 'tspan', { class: 'unlit' }, text);
    if (access === 'read') {
      copy.appendChild(builder.doc.createTextNode('R'));
      copy.appendChild(unlit('/W'));
    } else {
      copy.appendChild(unlit('R/'));
      copy.appendChild(builder.doc.createTextNode('W'));
    }

    addClasses(copy, 'lit');
    insertAfter(controls, copy);
    during(builder, copy, run);
  }
}

function drawLive(builder: Builder, path: string, indices: number[]): void {
  const wires = builder.element('live-wires');
  for (const run of runs(indices, builder.steps)) {
    const wire = create(
      builder.doc,
      'g',
      { class: 'live' },
      ...['live-casing', 'live-wire', 'live-current'].map(kind =>
        create(builder.doc, 'path', { class: kind, d: path })
      )
    );
    wires.appendChild(wire);
    during(builder, wire, run);
  }
}

function drawValues(builder: Builder, slot: string, changes: Change[]): void {
  const element = builder.element(slot);
  const drawnText = isDrawnText(element);
  let given = changes;
  if (drawnText && changes[0]?.index === START) {
    const drawn = textOf(element, slot).textContent;
    if (String(changes[0].value) !== drawn) {
      throw new Error(
        `"${slot}" is drawn holding "${drawn}", which is what it holds ` +
          `from the start, not "${changes[0].value}"`
      );
    }

    given = changes.slice(1);
  }

  given.forEach(({ index, value: held }, i) => {
    const next = given[i + 1];
    if (held === null) {
      return;
    }

    const run: Run =
      next === undefined ? { from: index } : { from: index, to: next.index };
    for (const shown of valueOf(builder, element, slot, held)) {
      during(builder, shown, run, { atRest: true });
    }
  });

  // The drawing itself shows what it holds until a step gives it a value;
  // marked once its copies are made, which must not take the mark.
  const first = given[0];
  if (drawnText && first !== undefined) {
    during(
      builder,
      element,
      { from: START, to: first.index },
      { atRest: true }
    );
  }
}

function bitsOf(element: Element): Element[] {
  return descendants(element, 'rect').filter(rect => hasClass(rect, 'bit'));
}

/**
 * Whether a slot is a text the drawing shows, which is neither a register nor
 * a template.
 */
function isDrawnText(element: Element): boolean {
  return bitsOf(element).length === 0 && !hasClass(element, 'transient');
}

function textOf(element: Element, slot: string): Element {
  const text =
    element.localName === 'text' ? element : firstDescendant(element, 'text');
  if (text === undefined) {
    throw new Error(`"${slot}" has no text to hold a value`);
  }

  return text;
}

/**
 * What shows a slot's value, put in the diagram after the slot, so that a
 * faded register still shows it as it is.
 */
function valueOf(
  builder: Builder,
  element: Element,
  slot: string,
  held: number | string
): Element[] {
  const bits = bitsOf(element);

  if (bits.length === 0) {
    const copy = copyOf(element);
    textOf(copy, slot).textContent = String(held);
    insertAfter(element, copy);
    return [copy];
  }

  if (typeof held !== 'number') {
    throw new Error(
      `"${slot}" is a register, and holds a number, not "${held}"`
    );
  }

  const digits = held.toString(2).padStart(bits.length, '0');
  if (digits.length > bits.length) {
    throw new Error(
      `${held} does not fit in the ${bits.length} bits of "${slot}"`
    );
  }

  const shown = create(
    builder.doc,
    'g',
    { class: 'register-value' },
    ...bits.map((rect, i) =>
      create(
        builder.doc,
        'text',
        {
          class: 'bit-value',
          x: number(rect, 'x') + number(rect, 'width') / 2,
          y: number(rect, 'y') + number(rect, 'height') / 2
        },
        digits[i] ?? ''
      )
    )
  );
  insertAfter(element, shown);

  const decimal = builder.doc.getElementById(`decimal-${slot}`);
  if (decimal === null) {
    return [shown];
  }

  const copy = copyOf(decimal);
  copy.textContent = String(held);
  insertAfter(decimal, copy);
  return [shown, copy];
}

function drawFocus(
  builder: Builder,
  parts: readonly string[],
  focused: ReadonlyMap<number, ReadonlySet<string>>
): void {
  for (const part of parts) {
    const faded = [...focused]
      .filter(([, about]) => !about.has(part))
      .map(([index]) => index)
      .sort((a, b) => a - b);
    if (faded.length > 0) {
      for (const element of builder.drawnAs(part)) {
        element.setAttribute('data-faded-at', faded.join(' '));
      }
    }
  }
}
