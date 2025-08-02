import 'iconify-icon';
import { icons } from '@iconify-json/fluent';
import mermaid from 'mermaid';
import Reveal from 'reveal.js';
import Highlight from 'reveal.js/plugin/highlight/highlight.esm.js';
import Markdown from 'reveal.js/plugin/markdown/markdown.esm.js';
import Notes from 'reveal.js/plugin/notes/notes.esm.js';
import Search from 'reveal.js/plugin/search/search.esm.js';

import 'reveal.js/plugin/highlight/monokai.css';
import 'reveal.js/dist/reveal.css';
import 'reveal.js/dist/theme/solarized.css';
import 'tippy.js/dist/tippy.css';
import './slides/git-memoirs';
import { GitMemoirController } from './slides/git-memoir';

const urlSearch = new URLSearchParams(window.location.search);
const printPdfMode = urlSearch.has('print-pdf');
const scrollMode = urlSearch.get('view') === 'scroll';

const deck = new Reveal({
  hash: true,
  markdown: {
    notesSeparator: '^\\*\\*Notes:\\*\\*',
    verticalSeparator: '^--v'
  },
  plugins: [
    Markdown,
    // Beware that the order of plugins matters! Highlight must be after
    // Markdown so that code blocks are highlighted correctly.
    Highlight,
    Notes,
    Search
  ],
  showNotes: getNotesMode(),
  slideNumber: 'c/t'
});

deck.initialize().then(() => {
  document.querySelectorAll('a:not([target="_blank"])').forEach(link => {
    link.setAttribute('target', '_blank');
  });

  mermaid.initialize({
    // Initialize mermaid on page load in print mode or scroll mode. Beware:
    // initializing mermaid on each slide in scroll mode seems to cause an
    // infinite loop.
    startOnLoad: printPdfMode || scrollMode,
    theme: 'dark'
  });

  GitMemoirController.start(deck);
});

if (!printPdfMode && !scrollMode) {
  deck.on('slidechanged', event => {
    const currentSlide = event['currentSlide'];
    if (currentSlide instanceof HTMLElement) {
      currentSlide.querySelectorAll<HTMLElement>('.mermaid').forEach(el => {
        mermaid
          .run({ nodes: [el] })
          .then(() => {
            deck.layout();
          })
          .catch((err: unknown) => {
            console.error('Mermaid rendering error:', err);
          });
      });
    } else {
      deck.layout();
    }
  });

  deck.on('slidetransitionend', () => {
    deck.layout();
  });
}

mermaid.registerIconPacks([
  {
    name: 'fluent',
    icons
  }
]);

if (urlSearch.has('export')) {
  (window as any)['Reveal'] = deck;
}

function getNotesMode(): boolean | 'separate-page' {
  const value = urlSearch.get('show-notes');
  if (value === '') {
    return true;
  } else if (value === 'true' || value === 'false') {
    return value === 'true';
  } else if (value === 'separate-page' || printPdfMode) {
    return 'separate-page';
  }

  return false;
}
