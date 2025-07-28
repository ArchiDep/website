export function isMacOs(): boolean {
  return (
    navigator.platform.toLowerCase().indexOf('mac') !== -1 ||
    navigator.platform.toLowerCase().indexOf('iphone') !== -1
  );
}

export function parseJsonSafe(value: string): unknown {
  try {
    return JSON.parse(value);
  } catch (e: unknown) {
    console.warn(`Failed to parse JSON: ${value}`, e);
    return undefined;
  }
}

export function required<T>(value: T, errorMessage: string): NonNullable<T> {
  if (value === null || value === undefined) {
    throw new Error(errorMessage);
  }

  return value;
}

export function toggleClass(
  element: Element,
  className: string,
  enabled: boolean
): void {
  if (enabled) {
    element.classList.add(className);
  } else {
    element.classList.remove(className);
  }
}
