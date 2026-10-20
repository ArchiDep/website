// The motion of a diagram that its stylesheet cannot do in every browser. It
// watches the classes reveal.js, or the page stepper, puts on the steps, so it
// works the same under both and needs neither.
//
// The file draws a diagram as it ends up. Four kinds of step change it on the
// way:
//
// - A hand-over: a connection is drawn to a listening port first
//   (`data-to-listener` on the edge), until its hand-over step, an empty
//   `.hand-over` step just before the edge, moves its end to the process that
//   takes it.
// - A fold: processes drawn one by one, each moved by its `data-unfolded`
//   offset, fold into the stacks they are drawn as once the `.fold` step is
//   reached; edges kept by the fold have their shape before it in
//   `data-unfolded-d`. The diagram has the `unfolded` class until then.
// - A teardown: an element with `data-gone-from` disappears once a step at that
//   index or later is reached, after its `--gone-delay` when it is its own
//   step.
// - A change of focus: a part with `data-faded-at` is faded, given the `faded`
//   class, while a step at one of those indices is the last one reached.
// - A reshape: once the `.reshape` step is reached, each part with
//   `data-reshaped-<attribute>` attributes moves to those values, after the
//   step's `--delay` and over its `--duration`, such as a diagram becoming the
//   one drawn on the next slide.
//
// Safari cannot set or animate a path's shape from CSS (the `d` property), so
// shapes are rewritten here, and positions set as transform attributes.

import { between, round } from './shapes';
import { fadedAt, reachedIndex } from './steps';

const MOVE_MS = 900;
// Points a shape is sampled at, when the two shapes it moves between are not
// drawn with the same commands.
const SAMPLES = 64;

type Shape = 'final' | 'unfolded' | 'listener';

interface State {
  readonly unfolded: boolean;
  readonly shapes: readonly Shape[];
}

interface Edge {
  readonly edge: Element;
  readonly path: SVGPathElement;
  readonly handOver: Element | null;
  readonly shapes: Readonly<Record<Shape, string>>;
}

interface Moved {
  readonly element: Element;
  readonly offset: readonly [number, number];
}

const ease = (t: number): number =>
  t < 0.5 ? 4 * t ** 3 : 1 - (-2 * t + 2) ** 3 / 2;

const reached = (element: Element | null): boolean =>
  element?.classList.contains('visible') ?? false;

const reducedMotion = (): boolean =>
  matchMedia('(prefers-reduced-motion: reduce)').matches;

/**
 * Start following the steps of a diagram.
 */
export function animate(svg: SVGSVGElement): void {
  if (svg.dataset['animated'] !== undefined) {
    return;
  }

  svg.dataset['animated'] = '';
  followShapes(svg);
  followReshape(svg);
  followTeardowns(svg);
  followFocus(svg);
}

function observeSteps(svg: SVGSVGElement, update: () => void): void {
  const observer = new MutationObserver(update);
  for (const fragment of svg.querySelectorAll('.fragment')) {
    observer.observe(fragment, { attributeFilter: ['class'] });
  }

  update();
}

function followShapes(svg: SVGSVGElement): void {
  const fold = svg.querySelector('.fragment.fold');
  const moved: Moved[] = [...svg.querySelectorAll('[data-unfolded]')].map(
    element => {
      const [x = 0, y = 0] = (element.getAttribute('data-unfolded') ?? '')
        .trim()
        .split(/[\s,]+/u)
        .map(Number);
      return { element, offset: [x, y] };
    }
  );
  const edges: Edge[] = [
    ...svg.querySelectorAll('[data-to-listener], [data-unfolded-d]')
  ].flatMap(edge => {
    const path = edge.querySelector('path');
    if (path === null) {
      return [];
    }

    const final = path.getAttribute('d') ?? '';
    const before = edge.previousElementSibling;
    return [
      {
        edge,
        path,
        handOver: before?.classList.contains('hand-over') ? before : null,
        shapes: {
          final,
          unfolded: edge.getAttribute('data-unfolded-d') ?? final,
          listener: edge.getAttribute('data-to-listener') ?? final
        }
      }
    ];
  });

  if (moved.length === 0 && edges.length === 0) {
    return;
  }

  // Fully drawn, with no step reached, is the diagram as it ends up: folded
  // and handed over.
  const state = (): State => {
    const unfolded =
      fold !== null &&
      !reached(fold) &&
      svg.querySelector('.fragment.visible') !== null;
    return {
      unfolded,
      shapes: edges.map(({ edge, handOver }) => {
        if (reached(edge) && handOver !== null && !reached(handOver)) {
          return 'listener';
        }

        return unfolded ? 'unfolded' : 'final';
      })
    };
  };

  const place = (from: State, to: State, t: number): void => {
    for (const { element, offset } of moved) {
      const [x0, y0] = from.unfolded ? offset : [0, 0];
      const [x1, y1] = to.unfolded ? offset : [0, 0];
      const x = x0 + (x1 - x0) * t;
      const y = y0 + (y1 - y0) * t;
      if (x || y) {
        element.setAttribute('transform', `translate(${x} ${y})`);
      } else {
        element.removeAttribute('transform');
      }
    }
  };

  let current: State | null = null;
  let frame = 0;

  observeSteps(svg, () => {
    const next = state();
    if (current !== null && sameState(current, next)) {
      return;
    }

    cancelAnimationFrame(frame);
    svg.classList.toggle('unfolded', next.unfolded);

    // Only a fold or a hand-over being reached moves things; anything else,
    // such as stepping back, puts them where they belong at once.
    const from = current;
    const folding =
      from !== null && from.unfolded && !next.unfolded && reached(fold);
    const handingOver = edges.some(
      ({ handOver }, i) =>
        from?.shapes[i] === 'listener' &&
        next.shapes[i] !== 'listener' &&
        reached(handOver)
    );
    current = next;

    if (from === null || !(folding || handingOver) || reducedMotion()) {
      place(next, next, 1);
      edges.forEach(({ path, shapes }, i) =>
        path.setAttribute('d', shapes[next.shapes[i] ?? 'final'])
      );
      return;
    }

    const morphs = edges.map(({ path, shapes }, i) =>
      morph(
        path,
        shapes[from.shapes[i] ?? 'final'],
        shapes[next.shapes[i] ?? 'final']
      )
    );
    const start = performance.now();
    const tick = (now: number): void => {
      const t = Math.min((now - start) / MOVE_MS, 1);
      place(from, next, ease(t));
      edges.forEach(({ path }, i) =>
        path.setAttribute('d', morphs[i]!(ease(t)))
      );
      if (t < 1) {
        frame = requestAnimationFrame(tick);
      }
    };
    frame = requestAnimationFrame(tick);
  });
}

function sameState(a: State, b: State): boolean {
  return (
    a.unfolded === b.unfolded &&
    a.shapes.every((shape, i) => shape === b.shapes[i])
  );
}

/**
 * A path's shape between two others. Two shapes drawn with the same commands
 * move number by number, which keeps a curve a curve; any other two are sampled
 * at as many points along their length, which a drawing tool rewriting path
 * data cannot break.
 */
function morph(
  path: SVGPathElement,
  from: string,
  to: string
): (t: number) => string {
  const alike = between(from, to);
  if (alike !== null) {
    return alike;
  }

  const pa = sample(path, from);
  const pb = sample(path, to);
  return t =>
    t >= 1
      ? to
      : 'M' +
        pa
          .map(
            (p, i) =>
              `${round(p.x + (pb[i]!.x - p.x) * t)},${round(p.y + (pb[i]!.y - p.y) * t)}`
          )
          .join(' L');
}

function sample(path: SVGPathElement, d: string): DOMPoint[] {
  const original = path.getAttribute('d') ?? '';
  path.setAttribute('d', d);
  const length = path.getTotalLength();
  const points = Array.from({ length: SAMPLES + 1 }, (_, i) =>
    path.getPointAtLength((length * i) / SAMPLES)
  );
  path.setAttribute('d', original);
  return points;
}

interface Reshaped {
  readonly element: Element;
  readonly name: string;
  readonly at: (t: number) => string;
}

/**
 * Parts moved to what their `data-reshaped-<attribute>` attributes say once
 * the `.reshape` step is reached. Only reaching it moves them; anything else,
 * such as stepping back, puts them where they belong at once.
 */
function followReshape(svg: SVGSVGElement): void {
  const marker = svg.querySelector('.fragment.reshape');
  if (marker === null) {
    return;
  }

  const prefix = 'data-reshaped-';
  const reshaped: Reshaped[] = [...svg.querySelectorAll('*')].flatMap(element =>
    [...element.attributes]
      .filter(({ name }) => name.startsWith(prefix))
      .map(({ name, value: to }) => {
        const attribute = name.slice(prefix.length);
        const from = element.getAttribute(attribute) ?? '';
        const at = between(from, to) ?? ((t: number) => (t < 1 ? from : to));
        return { element, name: attribute, at };
      })
  );

  const place = (t: number): void => {
    for (const { element, name, at } of reshaped) {
      element.setAttribute(name, at(t));
    }
  };

  const timing = (property: string): number =>
    (parseFloat(getComputedStyle(marker).getPropertyValue(property)) || 0) *
    1000;

  let current: boolean | null = null;
  let frame = 0;
  let timer = 0;

  observeSteps(svg, () => {
    const next = reached(marker);
    if (next === current) {
      return;
    }

    const from = current;
    current = next;
    cancelAnimationFrame(frame);
    window.clearTimeout(timer);

    if (from === null || !next || reducedMotion()) {
      place(next ? 1 : 0);
      return;
    }

    const duration = timing('--duration');
    timer = window.setTimeout(() => {
      const start = performance.now();
      const tick = (now: number): void => {
        const t = duration > 0 ? Math.min((now - start) / duration, 1) : 1;
        place(ease(t));
        if (t < 1) {
          frame = requestAnimationFrame(tick);
        }
      };
      frame = requestAnimationFrame(tick);
    }, timing('--delay'));
  });
}

/**
 * The index of the last step reached, or -1 if none is.
 */
function reachedOf(fragments: readonly Element[]): number {
  return reachedIndex(
    fragments.map(f => ({
      index: Number(f.getAttribute('data-fragment-index')),
      visible: f.classList.contains('visible')
    }))
  );
}

function followTeardowns(svg: SVGSVGElement): void {
  const leaving = [...svg.querySelectorAll('[data-gone-from]')];
  if (leaving.length === 0) {
    return;
  }

  const fragments = [...svg.querySelectorAll('.fragment')];
  const timers = new Map<Element, number>();

  observeSteps(svg, () => {
    const reached = reachedOf(fragments);

    for (const element of leaving) {
      const from = Number(element.getAttribute('data-gone-from'));
      if (reached < from) {
        window.clearTimeout(timers.get(element));
        timers.delete(element);
        // Only if there: removing a class that is not there still rewrites the
        // attribute, which is observed, and would run this again without end.
        if (element.classList.contains('gone')) {
          element.classList.remove('gone');
        }
        continue;
      }

      // Already gone, or waiting to be: marking another element gone is itself
      // observed, and must not restart this one's wait.
      if (element.classList.contains('gone') || timers.has(element)) {
        continue;
      }

      const delay =
        parseFloat(
          getComputedStyle(element).getPropertyValue('--gone-delay')
        ) || 0;
      if (reached === from && delay) {
        timers.set(
          element,
          window.setTimeout(() => {
            timers.delete(element);
            element.classList.add('gone');
          }, delay * 1000)
        );
      } else {
        element.classList.add('gone');
      }
    }
  });
}

/**
 * A part faded while the step reached is not about it (`data-faded-at`), which
 * its stylesheet draws paler. Nothing is faded in the fully drawn diagram, where
 * no step is reached.
 */
function followFocus(svg: SVGSVGElement): void {
  const parts = [...svg.querySelectorAll('[data-faded-at]')];
  if (parts.length === 0) {
    return;
  }

  const fragments = [...svg.querySelectorAll('.fragment')];
  observeSteps(svg, () => {
    const reached = reachedOf(fragments);
    for (const part of parts) {
      const faded = fadedAt(part.getAttribute('data-faded-at') ?? '', reached);
      // Only if it changes: rewriting the class of a part that is also a step
      // is observed, and would run this again without end.
      if (part.classList.contains('faded') !== faded) {
        part.classList.toggle('faded', faded);
      }
    }
  });
}
