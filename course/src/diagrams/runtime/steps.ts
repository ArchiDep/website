// Which step a diagram is at, worked out from what reveal.js, or the page
// stepper, says of each step: kept apart from the page so that it can be tested
// without one.

/**
 * What the stepping says of a step.
 */
export interface Fragment {
  readonly index: number;
  readonly visible: boolean;
}

/**
 * The index of the last step reached, or -1 if none is, as in the fully drawn
 * diagram and before the first step.
 */
export function reachedIndex(fragments: Iterable<Fragment>): number {
  let reached = -1;
  for (const { index, visible } of fragments) {
    if (visible && index > reached) {
      reached = index;
    }
  }

  return reached;
}

/**
 * Whether a part is faded at the step reached, given the indices of the steps
 * it is faded at, as the generator writes them in `data-faded-at`.
 */
export function fadedAt(steps: string, reached: number): boolean {
  return (
    reached >= 0 &&
    steps.split(/\s+/u).filter(Boolean).map(Number).includes(reached)
  );
}
