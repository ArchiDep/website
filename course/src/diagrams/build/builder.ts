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
 * Travelling data, drawn over the diagram rather than in it.
 */
export interface Overlay {
  readonly element: Element;
  /**
   * The second half of a trip in two clicks, until its step is known.
   */
  pendingLeg: Element | null;
}

/**
 * A diagram being turned into the steps that reveal it. The steps change a copy
 * of the drawing; the drawing itself is kept as it was drawn, which is where
 * positions are read from.
 */
export class Builder {
  readonly overlays: Overlay[] = [];
  /**
   * The processes given the layer and the cog that show them working.
   */
  readonly working = new Set<string>();
  /**
   * Whether a step has folded the processes drawn folded in the file.
   */
  folded = false;

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
}
