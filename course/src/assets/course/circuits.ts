// The logic circuits of a page, written with the `circuit` tag: a bar under
// each one, to put it back as it started, and to show it larger.
import type { LogicDiagramElement } from 'companion-gate';

export interface CircuitOptions {
  /**
   * Shows the circuit larger than the page can, with its instructions. The
   * button that calls it is only shown while the figure has the
   * `data-enlargeable` attribute, which whoever enlarges it decides.
   */
  readonly enlarge?: (figure: HTMLElement) => void;
}

/**
 * Give every circuit of a page its controls.
 */
export function setUpCircuits(
  root: ParentNode = document,
  { enlarge }: CircuitOptions = {}
): void {
  for (const figure of root.querySelectorAll<HTMLElement>('figure.circuit')) {
    const diagram = figure.querySelector<LogicDiagramElement>('logic-diagram');
    if (diagram === null) {
      continue;
    }

    const controls = circuitControls(diagram);
    if (enlarge) {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'enlarge';
      button.title = 'Show it as large as the window allows';
      button.textContent = '⤢ Enlarge';
      button.addEventListener('click', () => enlarge(figure));
      controls.append(button);
    }

    figure.append(controls);
  }
}

/**
 * A bar with a button that puts a circuit back as it started, so that its
 * instructions can be followed again from the first step.
 */
export function circuitControls(diagram: LogicDiagramElement): HTMLElement {
  const controls = document.createElement('div');
  controls.className = 'circuit-controls';

  const reset = document.createElement('button');
  reset.type = 'button';
  reset.className = 'reset';
  reset.title = 'Put it back as it started';
  reset.textContent = '↺ Reset';
  reset.addEventListener('click', () => diagram.reset());

  controls.append(reset);
  return controls;
}
