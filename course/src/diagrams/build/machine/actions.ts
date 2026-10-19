// What a step can do in a machine diagram. A step says what holds while it is
// the current one — what is lit, which wires are live, what each register
// holds, what it is about — and the vocabulary works out, once every step is
// known, how long each thing lasts: one copy of a lit cell for each stretch of
// steps it stays lit, one text for each value a register holds.
import type { Element } from '@xmldom/xmldom';

import { copyOf, during, reveal, runs, type Run } from '../actions';
import type { Action, Builder } from '../builder';
import {
  addClasses,
  childElements,
  create,
  descendants,
  firstDescendant,
  hasClass,
  insertAfter,
  number,
  removeClasses,
  rootOf
} from '../svg';

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
   * The step each cell is first used at, which its annotation appears at.
   */
  readonly annotated: Map<string, number>;
  /**
   * The steps the clock ticks at.
   */
  readonly ticks: Set<number>;
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
      annotated: new Map(),
      ticks: new Set(),
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
 * the drawing has one. Any other slot is copied with the value as its text: a
 * template drawn `transient`, such as a decoded field, or a text the drawing
 * shows, such as a cell's bits, which then shows its final value only at rest,
 * its values replacing it while stepping.
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
 * The processor uses the cell for the first time at this step, which its
 * annotation, the cell's `annotation` text, says what as. Until then, while
 * stepping, the annotation is hidden; the fully drawn diagram shows them all.
 */
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

export function annotate(cell: string): Action {
  return (builder, index) => {
    const annotated = machine(builder).annotated;
    if (!annotated.has(cell)) {
      annotated.set(cell, index);
    }
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

  // Before the values, whose copies of annotations it would take for the
  // drawing's own.
  drawAnnotations(builder, state.annotated);

  for (const [slot, changes] of state.values) {
    drawValues(builder, slot, changes);
  }

  for (const index of state.ticks) {
    drawTick(builder, index);
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
  changes.forEach(({ index, value: held }, i) => {
    const next = changes[i + 1];
    if (held === null) {
      return;
    }

    const run: Run =
      next === undefined ? { from: index } : { from: index, to: next.index };
    for (const shown of valueOf(builder, slot, held)) {
      during(builder, shown, run);
    }
  });
}

/**
 * What shows a slot's value, put in the diagram after the slot, so that a
 * faded register still shows it as it is.
 */
function valueOf(
  builder: Builder,
  slot: string,
  held: number | string
): Element[] {
  const element = builder.element(slot);
  const bits = descendants(element, 'rect').filter(rect =>
    hasClass(rect, 'bit')
  );

  if (bits.length === 0) {
    // Shown while stepping, even when what it is a copy of is not.
    const copy = copyOf(element);
    removeClasses(copy, 'at-rest');
    const text =
      copy.localName === 'text' ? copy : firstDescendant(copy, 'text');
    if (text === undefined) {
      throw new Error(`"${slot}" has no text to hold a value`);
    }

    if (!hasClass(element, 'transient')) {
      addClasses(element, 'at-rest');
    }

    text.textContent = String(held);
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

function drawAnnotations(
  builder: Builder,
  annotated: ReadonlyMap<string, number>
): void {
  for (const [cell, index] of annotated) {
    const annotation = firstDescendant(
      builder.element(cell),
      'text',
      'annotation'
    );
    if (annotation === undefined) {
      throw new Error(`"${cell}" is annotated, but has no annotation`);
    }

    reveal(annotation, index);
  }

  // Annotations no step reveals are those of cells the story does not use.
  for (const annotation of descendants(rootOf(builder.doc), 'text')) {
    if (
      hasClass(annotation, 'annotation') &&
      !hasClass(annotation, 'fragment')
    ) {
      addClasses(annotation, 'at-rest');
    }
  }
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
      builder.element(part).setAttribute('data-faded-at', faded.join(' '));
    }
  }
}
