import 'iconify-icon';
import Reveal from 'reveal.js';
import Highlight from 'reveal.js/plugin/highlight/highlight.esm.js';
import Markdown from 'reveal.js/plugin/markdown/markdown.esm.js';
import Notes from 'reveal.js/plugin/notes/notes.esm.js';
import Search from 'reveal.js/plugin/search/search.esm.js';

import 'reveal.js/dist/reveal.css';
import 'reveal.js/dist/theme/solarized.css';
import 'reveal.js/plugin/highlight/monokai.css';
import 'tippy.js/dist/tippy.css';
import './git-memoir/git-memoirs-registry';
import { startGitMemoirsForRevealDeck } from './slides/git-memoirs';

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

deck.initialize().then(async () => {
  // A deck's opening slide is set differently from the rest of it, and which
  // slide that is has to be marked on the slide itself rather than left to a
  // rule about where it sits: reveal rewrites the deck to print it, wrapping
  // every slide in a page of its own and putting the slide's background ahead
  // of it, so a rule keyed on position styles the title on screen and nothing
  // at all in a PDF.
  document
    .querySelector('.reveal .slides section')
    ?.classList.add('title-slide');

  document.querySelectorAll('a:not([target="_blank"])').forEach(link => {
    link.setAttribute('target', '_blank');
  });

  startGitMemoirsForRevealDeck(deck);
});

if (!printPdfMode && !scrollMode) {
  deck.on('slidetransitionend', () => {
    deck.layout();
  });
}

if (urlSearch.has('export')) {
  (window as any)['Reveal'] = deck;
}

window['deck'] = deck;

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
