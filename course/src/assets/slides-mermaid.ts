import { icons } from '@iconify-json/fluent';
import mermaid from 'mermaid';
import Reveal from 'reveal.js';

const urlSearch = new URLSearchParams(window.location.search);
const printPdfMode = urlSearch.has('print-pdf');
const scrollMode = urlSearch.get('view') === 'scroll';

const deck: Reveal.Api = window['deck'];

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
    const currentSlide = event['currentSlide'];
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
