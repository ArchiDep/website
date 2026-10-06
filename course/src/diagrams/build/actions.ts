// What a step can do. Each action names the elements it concerns by their ids
// in the drawing, and adds to them what the motion stylesheet and script need:
// the `fragment` class reveal.js and the page stepper key off, the index of
// the step, and the timings of its motion as custom properties.
import type { Document, Element } from '@xmldom/xmldom';

import type { Action, Builder, Overlay } from './builder';
import { ends, type Vector } from './path';
import {
  addClasses,
  boxOf,
  byId,
  commandOf,
  create,
  firstDescendant,
  insertAfter,
  pathOf,
  prepend,
  setVariables,
  type Box
} from './svg';
import {
  ARRIVED,
  DRAW,
  START,
  TYPE_START,
  round,
  seconds,
  typing
} from './timing';

/** What the course's prompt looks like. */
const PROMPT = '$>';
/** The cursor, a block as wide as a character of the monospace font. */
const CURSOR = '█';

function reveal(element: Element, index: number, ...classes: string[]): void {
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
 * A line typed at a prompt or into an application, then cleared on Enter. The
 * typed text is placed after the prompt in characters rather than in units of
 * the drawing, so that it follows whatever monospace font shows it.
 */
function typedLine(
  doc: Document,
  x: number,
  y: number,
  text: string,
  prompt: boolean
): Element {
  const at = prompt ? [...`${PROMPT} `].length : 0;
  const line = create(doc, 'g', { class: 'prompt', style: `--at: ${at}` });
  if (prompt) {
    line.appendChild(create(doc, 'text', { class: 'sign', x, y }, PROMPT));
  }

  line.appendChild(create(doc, 'text', { class: 'typed', x, y }, text));
  line.appendChild(create(doc, 'text', { class: 'cursor', x, y }, CURSOR));
  return line;
}

function typingVariables(
  text: string,
  extra: number
): Record<string, string | number> {
  const { duration, enter } = typing(text);
  return {
    chars: [...text].length,
    t0: seconds(TYPE_START),
    type: seconds(duration),
    enter: seconds(enter),
    launch: seconds(enter + extra)
  };
}

function offsetOf(doc: Document, id: string): Vector {
  const value = byId(doc, id).getAttribute('data-unfolded');
  if (!value) {
    return { x: 0, y: 0 };
  }

  const [x = 0, y = 0] = value
    .trim()
    .split(/[\s,]+/u)
    .map(Number);
  return { x, y };
}

export interface SpawnOptions {
  /**
   * The shell it is typed at, under whose box the prompt line is.
   */
  readonly shell?: string;
  /**
   * The control edge from the shell, drawn on Enter before the process.
   */
  readonly edge?: string;
}

/**
 * Typed at a prompt; Enter; the process starts. Under the shell's box when the
 * shell is drawn; otherwise just above where the process's box will be.
 */
export function spawned(
  node: string,
  { shell, edge }: SpawnOptions = {}
): Action {
  return (builder, index) => {
    const command = commandOf(builder.drawing, node);
    let x: number;
    let y: number;
    if (shell !== undefined) {
      let box: Box = boxOf(builder.drawing, shell);
      if (!builder.folded) {
        // Under the shell where it is before the fold, in the coordinates of
        // the process, which is moved by its own offset until then.
        const shellOffset = offsetOf(builder.drawing, shell);
        const nodeOffset = offsetOf(builder.drawing, node);
        box = {
          ...box,
          x: box.x + shellOffset.x - nodeOffset.x,
          y: box.y + shellOffset.y - nodeOffset.y
        };
      }

      x = box.x + 6;
      y = box.y + box.height + 18;
    } else {
      const box = boxOf(builder.drawing, node);
      x = box.x + 6;
      y = box.y - 12;
    }

    const element = builder.element(node);
    reveal(element, index, 'spawn');
    setVariables(
      element,
      typingVariables(command, edge !== undefined ? DRAW : START)
    );
    prepend(element, typedLine(builder.doc, x, y, command, true));

    if (edge !== undefined) {
      const edgeElement = builder.element(edge);
      reveal(edgeElement, index, 'fade-on');
      setVariables(edgeElement, { delay: seconds(typing(command).enter) });
    }
  };
}

/**
 * Typed into an application, without a prompt: an address into a browser, for
 * example. Clears on Enter.
 */
export function typedInto(node: string, text: string): Action {
  return (builder, index) => {
    const box = boxOf(builder.drawing, node);
    const element = builder.element(node);
    reveal(element, index, 'input');
    setVariables(element, typingVariables(text, 0));
    prepend(
      element,
      typedLine(builder.doc, box.x + 6, box.y + box.height + 18, text, false)
    );
  };
}

/**
 * Started by another process: its control edge appears, then it does.
 */
export function child(
  node: string,
  edge: string,
  { after = 0 }: { readonly after?: number } = {}
): Action {
  return (builder, index) => {
    const element = builder.element(node);
    reveal(element, index, 'child');
    setVariables(element, { launch: seconds(after + DRAW) });

    const edgeElement = builder.element(edge);
    reveal(edgeElement, index, 'fade-on');
    setVariables(edgeElement, { delay: seconds(after) });
  };
}

/**
 * A connection drawing itself from the side that opens it. If the edge says
 * where it first arrives, in `data-to-listener`, it goes there until a
 * hand-over moves its end to where it is drawn.
 */
export function connect(
  edge: string,
  { after = 0 }: { readonly after?: number } = {}
): Action {
  return (builder, index) => {
    const element = builder.element(edge);
    reveal(element, index, 'draw-on');
    setVariables(element, { delay: seconds(after) });
    // Drawn by a dash as long as the path, whatever its length or shape.
    pathOf(builder.doc, edge).setAttribute('pathLength', '1');
  };
}

/**
 * The listening process hands the connection over: its end moves from the
 * listening port to the process that takes it. Marked by an empty step just
 * before the edge, which the motion script finds it by.
 */
export function handOver(edge: string): Action {
  return (builder, index) => {
    const element = builder.element(edge);
    if (!element.getAttribute('data-to-listener')) {
      throw new Error(
        `"${edge}" is handed over, but does not say where it first arrives (data-to-listener)`
      );
    }

    const marker = create(builder.doc, 'g', {
      class: 'fragment hand-over',
      'data-fragment-index': index
    });
    element.parentNode?.insertBefore(marker, element);
  };
}

/**
 * The processes drawn folded in the file, drawn one by one until now, fold into
 * their stacks.
 */
export function fold(): Action {
  return (builder, index) => {
    builder.folded = true;
    builder.mark('fold', index);
  };
}

/**
 * Processes and connections that go away at this step, such as a session
 * closing. The fully drawn diagram still shows them. With `after`, they wait
 * for what takes them away to arrive, such as a keystroke.
 */
export function teardown(
  ids: readonly string[],
  { after = 0 }: { readonly after?: number } = {}
): Action {
  return (builder, index) => {
    builder.mark('teardown', index);
    for (const id of ids) {
      const element = builder.element(id);
      element.setAttribute('data-gone-from', String(index));
      if (after) {
        setVariables(element, { 'gone-delay': seconds(after) });
      }
    }
  };
}

/**
 * A cog centred on (cx, cy), drawn in place rather than translated, so that
 * measuring the diagram's shapes finds it where it is. Its hole is cut by the
 * even-odd fill rule.
 */
function cog(cx: number, cy: number): string {
  const teeth = 8;
  const outer = 7.5;
  const inner = 5.5;
  const hole = 2.3;
  const period = (2 * Math.PI) / teeth;
  const points: string[] = [];
  for (let i = 0; i < teeth; i++) {
    const a = i * period;
    for (const [offset, r] of [
      [-0.3, inner],
      [-0.14, outer],
      [0.14, outer],
      [0.3, inner]
    ] as const) {
      const angle = a + offset * period;
      points.push(
        `${(cx + r * Math.cos(angle)).toFixed(2)},${(cy + r * Math.sin(angle)).toFixed(2)}`
      );
    }
  }

  return (
    `M${points.join(' L')} Z ` +
    `M${round(cx + hole)},${round(cy)} A${hole},${hole} 0 1 0 ${round(cx - hole)},${round(cy)} ` +
    `A${hole},${hole} 0 1 0 ${round(cx + hole)},${round(cy)} Z`
  );
}

/**
 * The white layer and the cog that show a process working, added once per
 * process. The layer is a copy of the box rather than an animation of its
 * fill, which would replace the box's own animation.
 */
function workLayer(builder: Builder, node: string): void {
  if (builder.working.has(node)) {
    return;
  }

  builder.working.add(node);
  const box = boxOf(builder.drawing, node);
  const rect = firstDescendant(builder.element(node), 'rect');
  if (rect === undefined) {
    throw new Error(`"${node}" has no box`);
  }

  const glow = rect.cloneNode(false) as Element;
  addClasses(glow, 'glow');
  insertAfter(rect, glow);
  insertAfter(
    glow,
    create(
      builder.doc,
      'g',
      { class: 'cog' },
      create(builder.doc, 'path', {
        d: cog(box.x + box.width - 13, box.y + 13)
      })
    )
  );
}

/**
 * The process works while this step is the current one. Marked by an empty
 * step inside the process, which was revealed by an earlier step and may work
 * in several.
 */
export function pulse(node: string): Action {
  return (builder, index) => {
    workLayer(builder, node);
    builder.element(node).appendChild(
      create(builder.doc, 'g', {
        class: 'fragment pulse',
        'data-fragment-index': index
      })
    );
  };
}

/**
 * Typed at the shell's prompt, the process starts, works and exits, all in one
 * step: shown only while that step is the current one, so that neither the
 * fully drawn diagram nor later steps show it.
 */
export function shortLived(node: string, shell: string, edge: string): Action {
  return (builder, index) => {
    spawned(node, { shell, edge })(builder, index);
    workLayer(builder, node);
    const work = seconds(
      typing(commandOf(builder.drawing, node)).enter + DRAW + 0.5
    );
    for (const id of [node, edge]) {
      const element = builder.element(id);
      addClasses(element, 'passing');
      setVariables(element, { work });
    }
  };
}

export interface DataOptions {
  /**
   * Travels against the edge's arrow, from its end to its start.
   */
  readonly reverse?: boolean;
  /**
   * Travels at half speed, such as hundreds of files.
   */
  readonly heavy?: boolean;
}

/**
 * Data travelling along an edge, labelled with what travels and pointing the
 * way it goes. A trip is made in one click, or in two with a pause halfway,
 * where there is something to say.
 */
export interface Trip {
  /**
   * The whole way in one click.
   */
  whole(): Action;
  /**
   * To the middle of the edge, where it waits for `onward`.
   */
  toMiddle(): Action;
  /**
   * The rest of the way from the middle.
   */
  onward(): Action;
}

export function data(
  edge: string,
  text: string,
  options: DataOptions = {}
): Trip {
  let overlay: Overlay | null = null;
  return {
    whole: () => (builder, index) => {
      builder.overlays.push(packet(builder, index, edge, text, options, false));
    },
    toMiddle: () => (builder, index) => {
      overlay = packet(builder, index, edge, text, options, true);
      builder.overlays.push(overlay);
    },
    onward: () => (_builder, index) => {
      if (overlay === null || overlay.pendingLeg === null) {
        throw new Error(
          `"${text}" travels onward along "${edge}" without having set off`
        );
      }

      overlay.pendingLeg.setAttribute('data-fragment-index', String(index));
      overlay.pendingLeg = null;
    }
  };
}

function packet(
  builder: Builder,
  index: number,
  edge: string,
  text: string,
  { reverse = false, heavy = false }: DataOptions,
  halfway: boolean
): Overlay {
  const d = pathOf(builder.drawing, edge).getAttribute('d') ?? '';
  const { start, end } = ends(d);
  // Which way it points as it arrives.
  const arriving = reverse ? { x: -start.x, y: -start.y } : end;
  const half = Math.floor(6 + (8 * [...text].length) / 2);

  let shape: string;
  let flip: string | undefined;
  let textX: number;
  if (Math.abs(arriving.y) > Math.abs(arriving.x)) {
    // Along a vertical edge: the body stays level, its tip points down, or up
    // when flipped.
    const tip = 8;
    shape = `M${-half},-12 H${half} V12 H${tip} L0,${12 + tip} L${-tip},12 H${-half} Z`;
    flip = arriving.y < 0 ? 'scale(1,-1)' : undefined;
    textX = 0;
  } else {
    const tip = 10;
    shape =
      `M${-half - tip / 2},-12 H${half - tip / 2} L${half + tip / 2},0 ` +
      `L${half - tip / 2},12 H${-half - tip / 2} Z`;
    const leftward = arriving.x < 0;
    flip = leftward ? 'scale(-1,1)' : undefined;
    // The text is centred on the body, not on body and tip together.
    textX = leftward ? tip / 2 : -tip / 2;
  }

  const classes = ['overlay', 'packet', 'fragment'];
  if (!halfway) {
    classes.push('whole');
  }
  if (heavy) {
    classes.push('heavy');
  }

  // The path is followed as drawn; travelling against the arrow runs the
  // distance along it backwards.
  const leg = create(
    builder.doc,
    'g',
    {
      class: halfway ? 'leg fragment' : 'leg',
      style:
        `offset-path: path('${d}'); ` +
        `--from: ${reverse ? '100%' : '0%'}; --to: ${reverse ? '0%' : '100%'}`
    },
    create(builder.doc, 'path', { d: shape, transform: flip }),
    create(builder.doc, 'text', { x: textX, y: 5 }, text)
  );

  return {
    element: create(
      builder.doc,
      'g',
      { class: classes.join(' '), 'data-fragment-index': index },
      leg
    ),
    pendingLeg: halfway ? leg : null
  };
}

/**
 * When data travelling the whole way in one click has arrived.
 */
export { ARRIVED };
