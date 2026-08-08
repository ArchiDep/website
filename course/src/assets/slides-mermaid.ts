import { icons } from '@iconify-json/fluent';
import mermaid from 'mermaid';
import Reveal from 'reveal.js';

import { required } from './utils';

// What reveal.js hands a `slidechanged` listener. Its own types say only that
// it is an event, so the one field this reads is stated here.
type SlideChangedEvent = Event & { readonly currentSlide?: unknown };

const urlSearch = new URLSearchParams(window.location.search);
const printPdfMode = urlSearch.has('print-pdf');
const scrollMode = urlSearch.get('view') === 'scroll';

// The deck `src/assets/slides.ts` set up. This script is loaded beside it on a
// slides page and nowhere else, so a page with no deck is a mistake in the
// layout rather than something to draw around.
const deck: Reveal.Api = required(window['deck'], 'Reveal.js deck not found');

mermaid.initialize({
  startOnLoad: false,
  theme: 'dark'
});

// Initialize mermaid elements on page load in print mode or scroll mode.
if (printPdfMode || scrollMode) {
  const mermaidElements = [
    ...document.querySelectorAll<HTMLElement>('.mermaid')
  ];
  renderMermaidElements(mermaidElements);
} else {
  const currentSlide = deck.getCurrentSlide();
  const mermaidElements = [
    ...currentSlide.querySelectorAll<HTMLElement>('.mermaid')
  ];
  renderMermaidElements(mermaidElements);

  deck.on('slidechanged', event => {
    const currentSlide = (event as SlideChangedEvent).currentSlide;
    if (currentSlide instanceof HTMLElement) {
      const mermaidElements = [
        ...currentSlide.querySelectorAll<HTMLElement>('.mermaid')
      ];
      renderMermaidElements(mermaidElements);
    } else {
      deck.layout();
    }
  });
}

mermaid.registerIconPacks([
  {
    name: 'fluent',
    icons
  }
]);

async function renderMermaidElements(mermaidElements: readonly HTMLElement[]) {
  await Promise.all(
    mermaidElements.map(async el => {
      try {
        await mermaid.run({ nodes: [el] });
      } catch (err) {
        console.error('Mermaid rendering error:', err);
      } finally {
        el.classList.remove('loading');
      }
    })
  );

  deck.layout();
}
