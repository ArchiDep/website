// Durations as the motion stylesheet is given them.

export function seconds(value: number): string {
  return `${round(value)}s`;
}

export function round(value: number): number {
  return Math.round(value * 1000) / 1000;
}
