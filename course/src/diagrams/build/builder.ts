import type { Document, Element } from '@xmldom/xmldom';

import { byId, create, insertAfter } from './svg';

/**
 * Something a step reveals or does, applied at that step's index.
 */
export type Action = (builder: Builder, index: number) => void;

export interface Step {
  /**
   * The sentence the teacher says over the step, shown under the diagram in a
   * page. HTML.
   */
  readonly caption: string;
  readonly actions: readonly Action[];
}

export interface DiagramDefinition {
  readonly captions: {
    /**
     * Under the fully drawn diagram, which a page opens with. HTML.
     */
    readonly rest: string;
    /**
     * Once stepping starts, before the first step is reached. HTML.
     */
    readonly start: string;
  };
  readonly steps: readonly Step[];
}

/**
 * A diagram being turned into the steps that reveal it. The steps change a copy
 * of the drawing; the drawing itself is kept as it was drawn, which is where
 * positions are read from.
 *
 * What a vocabulary has to remember between steps, it keeps in its own state.
 */
export class Builder {
  /**
   * Drawn over the diagram rather than in it, such as travelling data: added
   * last, so that nothing in the drawing hides it.
   */
  readonly overlays: Element[] = [];
  readonly #checks: (() => void)[] = [];
  readonly #states = new Map<symbol, unknown>();

  constructor(
    readonly name: string,
    readonly drawing: Document,
    readonly doc: Document
  ) {}

  element(id: string): Element {
    return byId(this.doc, id);
  }

  /**
   * An empty group marking a step that changes the diagram without revealing
   * anything of it, which the motion script keys off. Put just after the
   * definitions, where it draws nothing.
   */
  mark(className: string, index: number): Element {
    const marker = create(this.doc, 'g', {
      class: `fragment ${className}`,
      'data-fragment-index': index
    });
    insertAfter(byId(this.doc, 'diagram-defs'), marker);
    return marker;
  }

  /**
   * A vocabulary's state for this diagram, created on first use.
   */
  state<T>(key: symbol, create: () => T): T {
    if (!this.#states.has(key)) {
      this.#states.set(key, create());
    }

    return this.#states.get(key) as T;
  }

  /**
   * Something to check once every step is built, such as a trip in two clicks
   * having been given its second.
   */
  check(check: () => void): void {
    this.#checks.push(check);
  }

  /**
   * Runs the checks, once every step is built.
   */
  finish(): void {
    for (const check of this.#checks) {
      check();
    }
  }
}
