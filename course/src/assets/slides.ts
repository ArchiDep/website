import 'iconify-icon';
import { icons } from '@iconify-json/fluent';
import mermaid from 'mermaid';
import Reveal from 'reveal.js';
import Highlight from 'reveal.js/plugin/highlight/highlight.esm.js';
import Markdown from 'reveal.js/plugin/markdown/markdown.esm.js';
import Notes from 'reveal.js/plugin/notes/notes.esm.js';
import Search from 'reveal.js/plugin/search/search.esm.js';

import 'reveal.js/dist/reveal.css';
import 'reveal.js/dist/theme/moon.css';

const urlSearch = new URLSearchParams(window.location.search);
const printPdfMode = urlSearch.has('print-pdf');

const deck = new Reveal({
  hash: true,
  markdown: {
    notesSeparator: '^\\*\\*Notes:\\*\\*'
  },
  plugins: [Highlight, Markdown, Notes, Search],
  showNotes: getNotesMode(),
  slideNumber: 'c/t'
});

deck.initialize().then(() => {
  document.querySelectorAll('a:not([target="_blank"])').forEach(link => {
    link.setAttribute('target', '_blank');
  });
});

mermaid.initialize({
  startOnLoad: true,
  theme: 'dark'
});

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
