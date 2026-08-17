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

// A deck's opening slide is set differently from the rest of it, and which
// slide that is has to be marked on the slide itself rather than left to a rule
// about which one comes first: every view but the default rewrites the deck,
// moving each slide into a page of its own, so a rule keyed on position styles
// the title in a browser and nothing at all in a PDF or a scrolled deck.
//
// The marking is a plugin because that is what runs at the right moment: reveal
// initializes plugins one after another in the order given here and only then
// builds a view, so a plugin after Markdown sees the slides it split out of the
// deck while they are still where it put them, and the mark travels with a
// slide into whatever page a view moves it into. Marking it after `initialize`
// would be too late: a scrolled deck leaves the emptied stacks of its vertical
// slides behind and ahead of the pages it builds, so the deck's opening slide
// is no longer the first one in the document.
const titleSlide = () => ({
  id: 'archidep-title-slide',
  init: (reveal: Reveal.Api) => {
    reveal.getSlides()[0]?.classList.add('title-slide');
  }
});

const deck = new Reveal({
  hash: true,
  markdown: {
    notesSeparator: '^\\*\\*Notes:\\*\\*',
    verticalSeparator: '^--v'
  },
  plugins: [
    Markdown,
    // Beware that the order of plugins matters! Both of these must be after
    // Markdown: Highlight so that the code blocks it converts are highlighted,
    // and the title slide so that there is a slide of the deck to mark.
    Highlight,
    titleSlide,
    Notes,
    Search
  ],
  showNotes: getNotesMode(),
  slideNumber: 'c/t'
});

deck.initialize().then(async () => {
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
