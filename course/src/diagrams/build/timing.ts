// How long the motion of a step takes, in seconds, where a step has to know it
// to time what follows. Everything else is timed by the motion stylesheet.

/**
 * Before the first keystroke.
 */
export const TYPE_START = 0.3;
/**
 * Between keystrokes, when the command is short enough.
 */
export const KEYSTROKE = 0.08;
/**
 * The longest typing may take: a longer command is typed faster.
 */
export const TYPING_CAP = 2;
/**
 * Between the last keystroke and Enter.
 */
export const ENTER = 0.4;
/**
 * For a control edge to appear before the process it starts.
 */
export const DRAW = 0.6;
/**
 * Between Enter and a process appearing, when no control edge is drawn.
 */
export const START = 0.2;
/**
 * For data travelling the whole way in one click to reach the other end.
 */
export const ARRIVED = 1.1;

export interface Typing {
  /** How long the keystrokes take. */
  readonly duration: number;
  /** When Enter is pressed, from the start of the step. */
  readonly enter: number;
}

export function typing(text: string): Typing {
  const chars = [...text].length;
  const duration = Math.min(chars * KEYSTROKE, TYPING_CAP);
  return { duration, enter: TYPE_START + duration + ENTER };
}

/**
 * When a process typed at a prompt has started: after Enter, its control edge
 * drawn first if there is one.
 */
export function launched(
  command: string,
  { edge = true }: { readonly edge?: boolean } = {}
): number {
  return typing(command).enter + (edge ? DRAW : START);
}

export function seconds(value: number): string {
  return `${round(value)}s`;
}

export function round(value: number): number {
  return Math.round(value * 1000) / 1000;
}
