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
  /**
   * What is shown from the start of stepping, before the first step: actions
   * given `START` as their index.
   */
  readonly start?: readonly Action[];
  readonly steps: readonly Step[];
}

/**
 * The index the actions of `start` are given: before the first step.
 */
export const START = -1;

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
  readonly #whenBuilt: (() => void)[] = [];
  readonly #states = new Map<symbol, unknown>();
  readonly #copies = new Map<string, Element[]>();

  constructor(
    readonly name: string,
    readonly drawing: Document,
    readonly doc: Document,
    /**
     * How many steps the diagram has.
     */
    readonly steps: number
  ) {}

  element(id: string): Element {
    return byId(this.doc, id);
  }

  /**
   * Records that a copy, which has no id of its own, stands for the part `id`,
   * such as a part of another drawing brought in.
   */
  copied(id: string, copy: Element): void {
    this.#copies.set(id, [...(this.#copies.get(id) ?? []), copy]);
  }

  /**
   * Every element a part is drawn as: the drawing's, if it has one, and the
   * copies standing for it.
   */
  drawnAs(id: string): Element[] {
    const element = this.doc.getElementById(id);
    const all = [
      ...(element === null ? [] : [element]),
      ...(this.#copies.get(id) ?? [])
    ];
    if (all.length === 0) {
      return [this.element(id)];
    }

    return all;
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
   * Something to do once every step is built: a check, such as a trip in two
   * clicks having been given its second, or what can only be drawn once every
   * step is known, such as how long something stays lit.
   */
  whenBuilt(callback: () => void): void {
    this.#whenBuilt.push(callback);
  }

  /**
   * Does what was left for when every step is built, in the order it was asked.
   */
  finish(): void {
    for (const callback of this.#whenBuilt) {
      callback();
    }
  }
}
