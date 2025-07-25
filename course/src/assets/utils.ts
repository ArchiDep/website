export function parseJsonSafe(value: string): unknown {
  try {
    return JSON.parse(value);
  } catch (e: unknown) {
    console.warn(`Failed to parse JSON: ${value}`, e);
    return undefined;
  }
}
