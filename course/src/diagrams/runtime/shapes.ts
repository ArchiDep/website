// An attribute's value between two others, such as a path's shape or a box's
// width: kept apart from the page so that it can be tested without one.

const NUMBER = /-?\d*\.?\d+(?:e[-+]?\d+)?/giu;

/**
 * The value between `from` and `to` at `t`, from 0 to 1, if the two are written
 * alike but for their numbers, such as two paths drawn with the same commands:
 * each number moves from one to the other, the rest staying as written. Null
 * for any other two.
 */
export function between(
  from: string,
  to: string
): ((t: number) => string) | null {
  if (from === to) {
    return () => to;
  }

  const a = from.match(NUMBER)?.map(Number) ?? [];
  const b = to.match(NUMBER)?.map(Number) ?? [];
  if (
    a.length !== b.length ||
    from.replace(NUMBER, '') !== to.replace(NUMBER, '')
  ) {
    return null;
  }

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

export function round(value: number): number {
  return Math.round(value * 100) / 100;
}
