// The `<coffee-queues>` element: people queueing at coffee machines, drawn as
// the simulation runs, with the coffees served per minute.
//
// Its steps are the fragments inside it: none shown is one row at one machine,
// the first a second row taking turns at the same machine, the second a second
// machine. It watches their classes, as the architecture diagrams do, so it
// needs no wiring to reveal.js. Reaching the next step plays it out; any other
// change, such as stepping back, starts the new setup as if it had always been.
//
// It runs only while it is on screen. A printed deck, which shows every
// fragment, and reduced motion get a still picture of the setup reached.

import {
  APPEAR,
  HEIGHT,
  LEAVE,
  MACHINE_X,
  ROW_Y,
  SETTLED,
  SETUPS,
  Simulation,
  TURN,
  WALK,
  WIDTH,
  placeOf,
  walking,
  type Machine,
  type Person,
  type Row,
  type Setup
} from './simulation';

const SVG = 'http://www.w3.org/2000/svg';

// Coloured as the two programs' bands on the slides that follow.
const ROW_COLORS: readonly [RowColor, RowColor] = [
  { line: '#1098ad', fill: '#c5f6fa' },
  { line: '#4263eb', fill: '#dbe4ff' }
];

interface RowColor {
  readonly line: string;
  readonly fill: string;
}

const COFFEE_COLOR = '#8d5524';
const INK = '#1d1d1f';
const MUTED = '#6e6e73';

// The figures and the machine, from the point where the feet or the base
// touch the floor.
const HEAD_Y = -78;
const HIP_Y = -34;
const SHOULDER_Y = -58;
const MACHINE_WIDTH = 80;
const MACHINE_HEIGHT = 130;
const CUP = { x: 30, y: -40, width: 20, height: 16 };

interface Figure {
  readonly group: SVGGElement;
  readonly legs: SVGPathElement;
  readonly arms: SVGPathElement;
  readonly cup: SVGGElement;
}

interface MachineDrawing {
  readonly group: SVGGElement;
  readonly coffee: SVGRectElement;
  readonly cup: SVGGElement;
  readonly stream: SVGRectElement;
}

interface Counter {
  readonly group: SVGGElement;
  readonly value: SVGTextElement;
}

const reducedMotion = (): boolean =>
  matchMedia('(prefers-reduced-motion: reduce)').matches;

const printing = (): boolean =>
  new URLSearchParams(window.location.search).has('print-pdf');

export class CoffeeQueuesElement extends HTMLElement {
  private svg: SVGSVGElement | null = null;
  private people: SVGGElement | null = null;
  private readonly figures = new Map<number, Figure>();
  private machines: MachineDrawing[] = [];
  private counters: { total: Counter; rows: [Counter, Counter] } | null = null;
  private simulation = new Simulation('one-row');
  private time = SETTLED;
  private frame = 0;
  private last: number | null = null;
  private visible = false;
  private readonly stepObserver = new MutationObserver(() => this.follow());
  private readonly screenObserver = new IntersectionObserver(entries => {
    this.visible = entries.some(entry => entry.isIntersecting);
    this.run();
  });

  connectedCallback(): void {
    if (this.svg === null) {
      this.draw();
    }

    for (const fragment of this.querySelectorAll('.fragment')) {
      this.stepObserver.observe(fragment, { attributeFilter: ['class'] });
    }

    this.screenObserver.observe(this);
    this.restart(this.reached());
  }

  disconnectedCallback(): void {
    this.stepObserver.disconnect();
    this.screenObserver.disconnect();
    this.visible = false;
    this.run();
  }

  private still(): boolean {
    return printing() || reducedMotion();
  }

  private reached(): Setup {
    const fragments = [...this.querySelectorAll('.fragment')];
    const shown = printing()
      ? fragments.length
      : fragments.filter(f => f.classList.contains('visible')).length;
    return SETUPS[Math.min(shown, SETUPS.length - 1)] ?? 'one-row';
  }

  private follow(): void {
    const setup = this.reached();
    if (setup === this.simulation.setup) {
      return;
    }

    const next = SETUPS[SETUPS.indexOf(this.simulation.setup) + 1];
    if (setup === next && !this.still()) {
      this.simulation.next(this.time);
      this.render();
    } else {
      this.restart(setup);
    }
  }

  /**
   * Starts a setup as if it had always been. Its people are numbered afresh,
   * so the figures drawn for the last one's go with them.
   */
  private restart(setup: Setup): void {
    for (const figure of this.figures.values()) {
      figure.group.remove();
    }

    this.figures.clear();
    this.simulation = new Simulation(setup);
    this.time = SETTLED;
    this.simulation.advance(this.time);
    this.render();
  }

  private run(): void {
    cancelAnimationFrame(this.frame);
    this.last = null;
    if (!this.visible || this.still()) {
      return;
    }

    const tick = (now: number): void => {
      // A frame long after the last, such as after the tab was hidden, does
      // not fast-forward the queues.
      const elapsed = this.last === null ? 0 : (now - this.last) / 1000;
      this.last = now;
      this.time += Math.min(elapsed, 0.1);
      this.simulation.advance(this.time);
      this.render();
      this.frame = requestAnimationFrame(tick);
    };

    this.frame = requestAnimationFrame(tick);
  }

  private draw(): void {
    if (this.style.display === '') {
      this.style.display = 'block';
    }

    const svg = element('svg', {
      viewBox: `0 0 ${WIDTH} ${HEIGHT}`,
      role: 'img',
      'aria-label':
        'People queueing at coffee machines, with the coffees served per minute',
      style: 'display: block; width: 100%; height: auto; font-family: inherit'
    });

    this.machines = [drawMachine(ROW_Y[0]), drawMachine(ROW_Y[1])];
    this.people = element('g', {});
    this.counters = {
      total: drawCounter(40, 52, INK, 'coffees per minute in total'),
      rows: [
        drawCounter(40, ROW_Y[0] - 40, ROW_COLORS[0].line, 'per minute'),
        drawCounter(40, ROW_Y[1] - 40, ROW_COLORS[1].line, 'per minute')
      ]
    };

    svg.append(
      ...this.machines.map(machine => machine.group),
      this.people,
      this.counters.total.group,
      ...this.counters.rows.map(counter => counter.group)
    );
    this.prepend(svg);
    this.svg = svg;
  }

  private render(): void {
    const { simulation, time, people, counters } = this;
    if (people === null || counters === null) {
      return;
    }

    const drawn = new Set<number>();
    for (const person of simulation.people()) {
      drawn.add(person.id);
      let figure = this.figures.get(person.id);
      if (figure === undefined) {
        figure = drawFigure(ROW_COLORS[person.row]);
        this.figures.set(person.id, figure);
      }

      // In the order given, which only changes when someone leaves.
      people.append(figure.group);
      placeFigure(figure, person, time);
    }

    for (const [id, figure] of this.figures) {
      if (!drawn.has(id)) {
        figure.group.remove();
        this.figures.delete(id);
      }
    }

    simulation.machines.forEach((machine, i) =>
      placeMachine(this.machines[i]!, machine, time)
    );

    counters.total.value.textContent = format(simulation.rate(time));
    counters.rows.forEach((counter, row) => {
      counter.value.textContent = format(simulation.rate(time, row as Row));
    });
    setOpacity(counters.rows[1].group, rowOpacity(simulation, time));
  }
}

function rowOpacity(simulation: Simulation, time: number): number {
  if (!simulation.second) {
    return 0;
  }

  const appears = simulation.rows[1][0]?.appears ?? null;
  return appears === null ? 1 : fade(appears, time);
}

// Fading in as they join a row, and out over the second half of their walk
// away with their coffee.
function opacityOf(person: Person, time: number): number {
  if (person.leaves !== null) {
    return Math.min(1, Math.max(0, 2 - (2 * (time - person.leaves)) / LEAVE));
  }

  return person.appears === null ? 1 : fade(person.appears, time);
}

function fade(start: number, time: number): number {
  return Math.min(1, Math.max(0, (time - start) / APPEAR));
}

function format(rate: number): string {
  return Number.isInteger(rate) ? String(rate) : rate.toFixed(1);
}

function element<K extends keyof SVGElementTagNameMap>(
  name: K,
  attributes: Readonly<Record<string, string | number>>
): SVGElementTagNameMap[K] {
  const created = document.createElementNS(SVG, name);
  for (const [key, value] of Object.entries(attributes)) {
    created.setAttribute(key, String(value));
  }

  return created;
}

function setOpacity(target: SVGElement, opacity: number): void {
  const value = opacity >= 1 ? '' : String(opacity);
  if (target.getAttribute('opacity') !== value) {
    if (value === '') {
      target.removeAttribute('opacity');
    } else {
      target.setAttribute('opacity', value);
    }
  }
}

function drawFigure(color: RowColor): Figure {
  const group = element('g', {
    fill: 'none',
    stroke: color.line,
    'stroke-width': 4,
    'stroke-linecap': 'round',
    'stroke-linejoin': 'round'
  });
  const legs = element('path', {});
  const arms = element('path', {});
  const cup = drawCup(16, -60, 11, 13);
  group.append(
    element('path', { d: `M0 ${HEAD_Y + 12} V${HIP_Y}` }),
    legs,
    arms,
    element('circle', { cx: 0, cy: HEAD_Y, r: 12, fill: color.fill }),
    cup
  );
  return { group, legs, arms, cup };
}

function drawCup(
  x: number,
  y: number,
  width: number,
  height: number
): SVGGElement {
  const cup = element('g', { stroke: '#495057', 'stroke-width': 2 });
  cup.append(
    element('rect', {
      x,
      y,
      width,
      height,
      rx: 2,
      fill: '#ffffff'
    }),
    element('rect', {
      x: x + 2,
      y: y + 2,
      width: width - 4,
      height: 3,
      fill: COFFEE_COLOR,
      stroke: 'none'
    })
  );
  return cup;
}

function placeFigure(figure: Figure, person: Person, time: number): void {
  const at = placeOf(person.motion, time);
  figure.group.setAttribute(
    'transform',
    `translate(${at.x.toFixed(1)} ${at.y.toFixed(1)})`
  );
  setOpacity(figure.group, opacityOf(person, time));

  const swing = walking(person.motion, time)
    ? Math.sin((time - person.motion.start) * 16) * 11
    : 10;
  figure.legs.setAttribute(
    'd',
    `M0 ${HIP_Y} L${swing.toFixed(1)} 0 M0 ${HIP_Y} L${(-swing).toFixed(1)} 0`
  );

  const holding = person.leaves !== null;
  figure.arms.setAttribute(
    'd',
    holding
      ? `M-14 -40 L0 ${SHOULDER_Y} L18 -48`
      : `M-14 -40 L0 ${SHOULDER_Y} L14 -40`
  );
  figure.cup.style.display = holding ? '' : 'none';
}

function drawMachine(floor: number): MachineDrawing {
  const group = element('g', { transform: `translate(${MACHINE_X} ${floor})` });
  const coffee = element('rect', {
    x: CUP.x + 2,
    width: CUP.width - 4,
    fill: COFFEE_COLOR
  });
  const stream = element('rect', {
    x: MACHINE_WIDTH / 2 - 2,
    y: -62,
    width: 4,
    height: CUP.y + 62,
    fill: COFFEE_COLOR
  });
  const cup = element('g', {});
  cup.append(
    element('rect', {
      ...CUP,
      rx: 2,
      fill: '#ffffff',
      stroke: '#495057',
      'stroke-width': 2
    }),
    coffee
  );

  group.append(
    element('rect', {
      x: 0,
      y: -MACHINE_HEIGHT,
      width: MACHINE_WIDTH,
      height: MACHINE_HEIGHT,
      rx: 8,
      fill: '#868e96',
      stroke: '#495057',
      'stroke-width': 3
    }),
    element('rect', {
      x: 12,
      y: -116,
      width: MACHINE_WIDTH - 24,
      height: 22,
      rx: 3,
      fill: '#e7f5ff',
      stroke: '#495057',
      'stroke-width': 2
    }),
    element('rect', {
      x: 12,
      y: -74,
      width: MACHINE_WIDTH - 24,
      height: 58,
      rx: 3,
      fill: '#343a40'
    }),
    element('rect', {
      x: MACHINE_WIDTH / 2 - 7,
      y: -74,
      width: 14,
      height: 12,
      fill: '#adb5bd'
    }),
    stream,
    cup
  );
  return { group, coffee, cup, stream };
}

function placeMachine(
  drawing: MachineDrawing,
  machine: Machine,
  time: number
): void {
  if (machine.shown === null) {
    drawing.group.style.display = 'none';
    return;
  }

  drawing.group.style.display = '';
  setOpacity(drawing.group, fade(machine.shown, time));

  const serving = machine.serving !== null;
  const poured = Math.min(
    1,
    Math.max(0, (time - machine.pours) / (TURN - WALK))
  );
  const height = (CUP.height - 3) * poured;
  drawing.cup.style.display = serving ? '' : 'none';
  drawing.coffee.setAttribute('y', String(CUP.y + CUP.height - 1 - height));
  drawing.coffee.setAttribute('height', String(height));
  drawing.stream.style.display =
    serving && poured > 0 && poured < 1 ? '' : 'none';
}

function drawCounter(
  x: number,
  y: number,
  color: string,
  label: string
): Counter {
  const group = element('g', {});
  const value = element('text', {
    x,
    y,
    fill: color,
    'font-size': 44,
    'font-weight': 'bold'
  });
  const caption = element('text', {
    x,
    y: y + 24,
    fill: MUTED,
    'font-size': 18
  });
  caption.textContent = label;
  group.append(value, caption);
  return { group, value };
}

/**
 * Defines the `<coffee-queues>` element.
 */
export function defineCoffeeQueuesElement(): void {
  if (customElements.get('coffee-queues') === undefined) {
    customElements.define('coffee-queues', CoffeeQueuesElement);
  }
}
