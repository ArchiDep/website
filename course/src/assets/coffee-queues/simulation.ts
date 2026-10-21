// People queueing at coffee machines, the analogy of concurrency and
// parallelism: one row at one machine; two rows taking turns at the one
// machine; two rows at two machines. A machine serves one person per turn, so
// the second row halves what each row is served without changing the total,
// and the second machine doubles it.
//
// The simulation is driven by a clock in seconds and knows nothing of the DOM:
// at each turn, every machine shown hands its coffee to the person it served,
// who leaves, and calls the next person, from the row whose turn it is. What
// is drawn at any moment, people walking included, is worked out from the
// motions those turns start.

export type Row = 0 | 1;

/**
 * What the queues look like: one row, two rows at one machine, or two rows at
 * two machines.
 */
export type Setup = 'one-row' | 'two-rows' | 'two-machines';

export const SETUPS: readonly Setup[] = ['one-row', 'two-rows', 'two-machines'];

export interface Point {
  readonly x: number;
  readonly y: number;
}

/**
 * How long things take on screen, in seconds: walking to the machine, which
 * is also how long a row takes to move forward, and a whole turn, a coffee
 * being made in what is left of it.
 */
export const WALK = 0.6;
export const TURN = 2;
export const LEAVE = 1.2;
export const APPEAR = 0.6;

/**
 * How long a coffee is said to take, in seconds, which sets how much faster
 * than real time the animation runs.
 */
export const COFFEE = 30;

/**
 * How far back the rates are measured, on screen: two turns, so that a row
 * served every other turn is counted as steadily as one served every turn.
 */
export const RATE_WINDOW = 2 * TURN;

/**
 * When a new simulation is first shown, far enough in for the rates to be
 * measured over a whole window, and in the middle of a coffee being made, so
 * that a still picture shows everyone in place.
 */
export const SETTLED = 3 * TURN + WALK + (TURN - WALK) / 2;

export const WIDTH = 960;
export const HEIGHT = 580;
export const ROW_Y: readonly [number, number] = [250, 450];
export const FRONT_X = 680;
export const SPACING = 64;
export const ROW_LENGTH = 7;
export const MACHINE_X = 790;
export const SERVICE_X = 760;
// Where people walk off to with their coffee, fading out on the way: away
// from the other row.
const EXIT_Y: readonly [number, number] = [ROW_Y[0] - 110, ROW_Y[1] + 110];

export interface Motion {
  readonly from: Point;
  readonly to: Point;
  readonly start: number;
  readonly duration: number;
}

export interface Person {
  readonly id: number;
  readonly row: Row;
  motion: Motion;
  /**
   * When the person starts fading in, if they appear rather than having been
   * there from the start.
   */
  appears: number | null;
  /**
   * When the person leaves with their coffee, if they have been served.
   */
  leaves: number | null;
}

export interface Machine {
  readonly index: Row;
  /**
   * When the machine starts fading in, if it appears rather than having been
   * there from the start, or null while it is not there.
   */
  shown: number | null;
  serving: Person | null;
  /**
   * When the coffee being made started pouring.
   */
  pours: number;
  /**
   * The row whose turn is next, when it serves both.
   */
  turn: Row;
}

export interface Served {
  readonly row: Row;
  readonly at: number;
}

/**
 * Where a person waits in a row: 0 is the front.
 */
export function spot(row: Row, place: number): Point {
  return { x: FRONT_X - place * SPACING, y: ROW_Y[row] };
}

/**
 * Where a machine's customer stands while their coffee is made.
 */
export function service(machine: Row): Point {
  return { x: SERVICE_X, y: ROW_Y[machine] };
}

/**
 * Where a person is at a time, eased along their motion.
 */
export function placeOf(motion: Motion, time: number): Point {
  const t = progress(motion, time);
  const eased = (1 - Math.cos(Math.PI * t)) / 2;
  return {
    x: motion.from.x + (motion.to.x - motion.from.x) * eased,
    y: motion.from.y + (motion.to.y - motion.from.y) * eased
  };
}

/**
 * Whether a person is walking at a time.
 */
export function walking(motion: Motion, time: number): boolean {
  const t = progress(motion, time);
  return t > 0 && t < 1;
}

function progress(motion: Motion, time: number): number {
  if (motion.duration <= 0) {
    return 1;
  }

  return Math.min(1, Math.max(0, (time - motion.start) / motion.duration));
}

function still(at: Point): Motion {
  return { from: at, to: at, start: 0, duration: 0 };
}

export class Simulation {
  readonly rows: [Person[], Person[]] = [[], []];
  readonly machines: [Machine, Machine];
  readonly leaving: Person[] = [];
  readonly served: Served[] = [];
  setup: Setup;
  /**
   * Whether the second row is there.
   */
  second: boolean;
  private nextTurn = 0;
  private nextId = 0;

  /**
   * A simulation of a setup as it is from the start, with its first turn at
   * time 0.
   */
  constructor(setup: Setup) {
    this.setup = setup;
    this.second = setup !== 'one-row';
    this.machines = [
      { index: 0, shown: -Infinity, serving: null, pours: 0, turn: 0 },
      {
        index: 1,
        shown: setup === 'two-machines' ? -Infinity : null,
        serving: null,
        pours: 0,
        turn: 1
      }
    ];

    this.fill(0, -Infinity);
    if (this.second) {
      this.fill(1, -Infinity);
    }
  }

  /**
   * Plays every turn up to a time.
   */
  advance(time: number): void {
    while (this.nextTurn <= time) {
      this.playTurn(this.nextTurn);
      this.nextTurn += TURN;
    }

    for (let i = this.leaving.length - 1; i >= 0; i--) {
      const person = this.leaving[i]!;
      if (person.motion.start + person.motion.duration < time) {
        this.leaving.splice(i, 1);
      }
    }
  }

  /**
   * Moves on to the next setup at a time: the second row appears, taking the
   * next turn at the one machine, or the second machine appears, taking the
   * second row from the next turn on. Any other change is a new simulation.
   */
  next(at: number): Setup {
    if (this.setup === 'one-row') {
      this.second = true;
      this.fill(1, at);
      this.machines[0].turn = 1;
      this.setup = 'two-rows';
      return this.setup;
    }

    this.machines[1].shown = at;
    this.setup = 'two-machines';
    return this.setup;
  }

  /**
   * The coffees served per minute, as if a coffee took `COFFEE` seconds, over
   * the last `RATE_WINDOW` seconds: to one row, or to both.
   */
  rate(time: number, row?: Row): number {
    const count = this.served.filter(
      served =>
        served.at <= time &&
        served.at > time - RATE_WINDOW &&
        (row === undefined || served.row === row)
    ).length;

    return (count * 60) / ((RATE_WINDOW * COFFEE) / TURN);
  }

  /**
   * Everyone drawn, those leaving first so that whoever takes their place at
   * the machine is drawn over them.
   */
  people(): Person[] {
    return [
      ...this.leaving,
      ...this.rows[0],
      ...this.rows[1],
      ...this.machines.flatMap(machine =>
        machine.serving === null ? [] : [machine.serving]
      )
    ];
  }

  private fill(row: Row, appears: number): void {
    this.rows[row] = Array.from({ length: ROW_LENGTH }, (_, place) => ({
      id: this.nextId++,
      row,
      motion: still(spot(row, place)),
      appears: appears === -Infinity ? null : appears,
      leaves: null
    }));
  }

  private playTurn(at: number): void {
    for (const machine of this.machines) {
      if (machine.shown === null) {
        continue;
      }

      this.handOver(machine, at);
      const row = this.rowFor(machine);
      if (row !== null) {
        this.call(machine, row, at);
      }
    }

    this.served.splice(
      0,
      this.served.findIndex(served => served.at > at - RATE_WINDOW)
    );
  }

  private handOver(machine: Machine, at: number): void {
    const person = machine.serving;
    if (person === null) {
      return;
    }

    machine.serving = null;
    person.leaves = at;
    const from = service(machine.index);
    person.motion = {
      from,
      to: { x: from.x, y: EXIT_Y[machine.index] },
      start: at,
      duration: LEAVE
    };
    this.leaving.push(person);
    this.served.push({ row: person.row, at });
  }

  /**
   * The row a machine serves next: the first machine serves the second row
   * too, in turn with the first, until the second machine is there.
   */
  private rowFor(machine: Machine): Row | null {
    if (machine.index === 1) {
      return this.second ? 1 : null;
    }

    if (!this.second || this.machines[1].shown !== null) {
      return 0;
    }

    const row = machine.turn;
    machine.turn = row === 0 ? 1 : 0;
    return row;
  }

  private call(machine: Machine, row: Row, at: number): void {
    const queue = this.rows[row];
    const front = queue.shift();
    if (front === undefined) {
      return;
    }

    front.motion = {
      from: placeOf(front.motion, at),
      to: service(machine.index),
      start: at,
      duration: WALK
    };
    machine.serving = front;
    machine.pours = at + WALK;

    queue.forEach((person, place) => {
      person.motion = {
        from: placeOf(person.motion, at),
        to: spot(row, place),
        start: at,
        duration: WALK
      };
    });

    queue.push({
      id: this.nextId++,
      row,
      motion: {
        from: spot(row, ROW_LENGTH),
        to: spot(row, ROW_LENGTH - 1),
        start: at,
        duration: WALK
      },
      appears: at,
      leaves: null
    });
  }
}
