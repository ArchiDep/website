// Diagrams in a reveal.js deck. reveal.js does the stepping itself, its
// fragments being the diagram's steps; what is left is the motion, the legend,
// and printing.
import type Reveal from 'reveal.js';

import { viewBoxWithoutLegend } from './fit';
import { animate } from './motion';

/**
 * A plugin to put after the Markdown plugin, which is what puts the diagrams
 * into the slides.
 */
export function diagramsPlugin({
  print
}: {
  readonly print: boolean;
}): () => Reveal.Plugin {
  return () => ({
    id: 'archidep-diagrams',
    init: (deck: Reveal.Api): void => {
      for (const figure of deck
        .getSlidesElement()
        ?.querySelectorAll<HTMLElement>('.diagram-figure') ?? []) {
        setUp(figure, print);
      }

      if (!print) {
        // The legend is hidden, and the gap it leaves taken away, which can
        // only be measured once a slide is shown.
        const fit = (): void => fitDiagrams(deck.getCurrentSlide());
        deck.on('ready', fit);
        deck.on('slidechanged', fit);
      }
    }
  });
}

function setUp(figure: HTMLElement, print: boolean): void {
  figure.classList.add('in-deck');
  const svg = figure.querySelector<SVGSVGElement>('svg.diagram');
  if (svg === null) {
    return;
  }

  if (print) {
    // A printed deck shows each slide once with every step reached, which is
    // not the fully drawn diagram: a step may tear down what an earlier one
    // showed. Without its steps, a diagram prints fully drawn, legend included.
    figure.classList.add('printed');
    for (const step of svg.querySelectorAll('.fragment')) {
      step.classList.remove('fragment');
    }
  }

  animate(svg);
}

function fitDiagrams(slide: HTMLElement | undefined): void {
  for (const svg of slide?.querySelectorAll<SVGSVGElement>(
    '.diagram-figure svg.diagram:not([data-fitted])'
  ) ?? []) {
    const viewBox = viewBoxWithoutLegend(svg);
    if (viewBox !== null) {
      svg.setAttribute('viewBox', viewBox);
      svg.dataset['fitted'] = '';
    }
  }
}
