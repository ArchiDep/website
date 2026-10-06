// What travelling data needs to know of an edge: which way it points where it
// starts and where it ends. Inkscape writes path data in any of its forms,
// relative commands and arcs included, so all of them are read; the shape
// itself is left to the browser, which follows the path data as written.

export interface Vector {
  readonly x: number;
  readonly y: number;
}

export interface Ends {
  /**
   * The direction a path leaves its first point in.
   */
  readonly start: Vector;
  /**
   * The direction a path arrives at its last point in.
   */
  readonly end: Vector;
}

const COMMAND = /([MmLlHhVvCcSsQqTtAaZz])([^MmLlHhVvCcSsQqTtAaZz]*)/gu;
const NUMBER = /[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?/gu;

const ARITY: Readonly<Record<string, number>> = {
  M: 2,
  L: 2,
  H: 1,
  V: 1,
  C: 6,
  S: 4,
  Q: 4,
  T: 2,
  A: 7,
  Z: 0
};

interface Segment {
  readonly from: Vector;
  readonly to: Vector;
  // The control points nearest to each end, which give the tangents of a curve;
  // a straight segment has none.
  readonly near: readonly Vector[];
}

export function ends(d: string): Ends {
  const segments = segmentsOf(d);
  const first = segments[0];
  const last = segments[segments.length - 1];
  if (first === undefined || last === undefined) {
    throw new Error(`The path "${d}" draws nothing`);
  }

  return {
    start: direction(first.from, [...first.near, first.to]),
    end: direction(last.to, [...last.near].reverse().concat(last.from), true)
  };
}

// The first point that is not where the end is gives the direction. A curve
// whose control point sits on its end point is tangent to the next one.
function direction(at: Vector, towards: Vector[], arriving = false): Vector {
  for (const point of towards) {
    const dx = point.x - at.x;
    const dy = point.y - at.y;
    if (Math.hypot(dx, dy) > 1e-9) {
      return arriving ? { x: -dx, y: -dy } : { x: dx, y: dy };
    }
  }

  throw new Error('A segment of the path has no length');
}

function segmentsOf(d: string): Segment[] {
  const segments: Segment[] = [];
  let current: Vector = { x: 0, y: 0 };
  let subpathStart: Vector = current;
  let lastControl: Vector | null = null;
  let lastCommand = '';

  for (const [, letter = '', args = ''] of d.matchAll(COMMAND)) {
    const command = letter.toUpperCase();
    const relative = letter !== command;
    const numbers = [...args.matchAll(NUMBER)].map(m => Number(m[0]));
    const arity = ARITY[command] ?? 0;

    if (command === 'Z') {
      if (current.x !== subpathStart.x || current.y !== subpathStart.y) {
        segments.push({ from: current, to: subpathStart, near: [] });
      }

      current = subpathStart;
      lastControl = null;
      lastCommand = command;
      continue;
    }

    if (numbers.length === 0 || numbers.length % arity !== 0) {
      throw new Error(`Cannot read "${letter}${args}" in the path "${d}"`);
    }

    for (let i = 0; i < numbers.length; i += arity) {
      const n = numbers.slice(i, i + arity);
      const point = (xi: number, yi: number): Vector => ({
        x: (n[xi] ?? 0) + (relative ? current.x : 0),
        y: (n[yi] ?? 0) + (relative ? current.y : 0)
      });
      // A moveto followed by more coordinates draws lines to them.
      const effective = command === 'M' && i > 0 ? 'L' : command;
      const from = current;

      switch (effective) {
        case 'M':
          current = point(0, 1);
          subpathStart = current;
          lastControl = null;
          break;
        case 'L':
        case 'T': {
          const to = point(0, 1);
          const control: Vector | null =
            effective === 'T' &&
            lastControl !== null &&
            /[QT]/u.test(lastCommand)
              ? reflect(lastControl, from)
              : null;
          segments.push({ from, to, near: control ? [control] : [] });
          current = to;
          lastControl = control;
          break;
        }
        case 'H': {
          const to = { x: (n[0] ?? 0) + (relative ? from.x : 0), y: from.y };
          segments.push({ from, to, near: [] });
          current = to;
          lastControl = null;
          break;
        }
        case 'V': {
          const to = { x: from.x, y: (n[0] ?? 0) + (relative ? from.y : 0) };
          segments.push({ from, to, near: [] });
          current = to;
          lastControl = null;
          break;
        }
        case 'C': {
          const c1 = point(0, 1);
          const c2 = point(2, 3);
          const to = point(4, 5);
          segments.push({ from, to, near: [c1, c2] });
          current = to;
          lastControl = c2;
          break;
        }
        case 'S': {
          const c1 =
            lastControl !== null && /[CS]/u.test(lastCommand)
              ? reflect(lastControl, from)
              : from;
          const c2 = point(0, 1);
          const to = point(2, 3);
          segments.push({ from, to, near: [c1, c2] });
          current = to;
          lastControl = c2;
          break;
        }
        case 'Q': {
          const c = point(0, 1);
          const to = point(2, 3);
          segments.push({ from, to, near: [c] });
          current = to;
          lastControl = c;
          break;
        }
        case 'A': {
          // An arc's tangents are approximated by its chord, which is enough
          // to tell which way data travelling along it points.
          const to = point(5, 6);
          segments.push({ from, to, near: [] });
          current = to;
          lastControl = null;
          break;
        }
      }

      lastCommand = effective;
    }
  }

  return segments;
}

function reflect(control: Vector, about: Vector): Vector {
  return { x: 2 * about.x - control.x, y: 2 * about.y - control.y };
}
