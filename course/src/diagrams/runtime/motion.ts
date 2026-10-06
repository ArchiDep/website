// The motion of a diagram that its stylesheet cannot do in every browser. It
// watches the classes reveal.js, or the page stepper, puts on the steps, so it
// works the same under both and needs neither.
//
// The file draws a diagram as it ends up. Three kinds of step change it on the
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
//   index or later is reached, after its `--gone-delay` when it is its own step.
//
// Safari cannot set or animate a path's shape from CSS (the `d` property), so
// shapes are rewritten here, and positions set as transform attributes.

const MOVE_MS = 900;
// Points a shape is sampled at, when the two shapes it moves between are not
// drawn with the same commands.
const SAMPLES = 64;
const NUMBER = /-?\d*\.?\d+(?:e[-+]?\d+)?/giu;

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
  followTeardowns(svg);
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
  if (from === to) {
    return () => to;
  }

  const a = from.match(NUMBER)?.map(Number) ?? [];
  const b = to.match(NUMBER)?.map(Number) ?? [];
  if (
    a.length === b.length &&
    from.replace(NUMBER, '') === to.replace(NUMBER, '')
  ) {
    const parts = to.split(NUMBER);
    return t =>
      t >= 1
        ? to
        : parts
            .map((part, i) =>
              i < b.length ? part + round(a[i]! + (b[i]! - a[i]!) * t) : part
            )
            .join('');
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

function round(value: number): number {
  return Math.round(value * 100) / 100;
}

function followTeardowns(svg: SVGSVGElement): void {
  const leaving = [...svg.querySelectorAll('[data-gone-from]')];
  if (leaving.length === 0) {
    return;
  }

  const fragments = [...svg.querySelectorAll('.fragment')];
  const timers = new Map<Element, number>();

  observeSteps(svg, () => {
    const reachedIndex = Math.max(
      -1,
      ...fragments
        .filter(f => f.classList.contains('visible'))
        .map(f => Number(f.getAttribute('data-fragment-index')))
    );

    for (const element of leaving) {
      const from = Number(element.getAttribute('data-gone-from'));
      if (reachedIndex < from) {
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
      if (reachedIndex === from && delay) {
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
