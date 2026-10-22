import {
  defineLogicDiagramElement,
  defineTruthTableElement,
  RevealLogicDiagrams
} from 'companion-gate';
import 'iconify-icon';
import Reveal, { type RevealApi } from 'reveal.js';
import Highlight from 'reveal.js/plugin/highlight';
import Markdown from 'reveal.js/plugin/markdown';
import Notes from 'reveal.js/plugin/notes';
import Search from 'reveal.js/plugin/search';

import 'reveal.js/reveal.css';
import 'reveal.js/theme/solarized.css';
import 'reveal.js/plugin/highlight/monokai.css';
import 'tippy.js/dist/tippy.css';
import { diagramsPlugin } from '../diagrams/runtime';
import { defineCoffeeQueuesElement } from './coffee-queues';
// The embeds need no reveal.js lifecycle wiring: each one defers on its own
// IntersectionObserver and replays when its slide comes back.
import { defineStoryElement } from './simgit';

defineCoffeeQueuesElement();
defineStoryElement();
defineLogicDiagramElement();
defineTruthTableElement();

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
  init: (reveal: RevealApi) => {
    reveal.getSlides()[0]?.classList.add('title-slide');
  }
});

// A slide's corner title (an `h3` with the `corner-title` class) is drawn in
// the slide's own corner by the stylesheet, which is what a PDF or a scrolled
// deck shows. Presented, it moves to the window's corner instead, outside the
// scaled slide, so that the slide's content gets the space: reveal scales the
// slides with a transform, which a fixed element inside them cannot escape, so
// the window's box is a separate element that mirrors the current slide's
// title, shown only once the title's fragment is.
const cornerTitle = () => ({
  id: 'archidep-corner-title',
  init: (reveal: RevealApi) => {
    const box = document.createElement('div');
    box.className = 'corner-title-window';
    box.setAttribute('aria-live', 'polite');
    box.hidden = true;
    document.body.append(box);
    reveal.getRevealElement()?.classList.add('corner-title-in-window');

    const update = () => {
      const title = reveal
        .getCurrentSlide()
        ?.querySelector(':scope > h3.corner-title');
      const shown =
        title !== null &&
        title !== undefined &&
        (!title.classList.contains('fragment') ||
          title.classList.contains('visible'));

      box.textContent = shown ? title.textContent : '';
      box.hidden = !shown;
    };

    for (const event of [
      'ready',
      'slidechanged',
      'fragmentshown',
      'fragmenthidden'
    ]) {
      reveal.on(event, update);
    }
  }
});

// A slide marked `data-transition="none"` follows on from the one before it,
// such as a diagram becoming the one drawn on the next slide, and going back to
// that one must not show a transition either. But reveal moves a slide in with
// its own transition, which the slide before cannot give up without also
// losing it from the slide before that. So it takes "none" only while the slide
// following on from it is shown, and gets its own back once it is shown again,
// after the frame that puts it in place.
const followingOn = () => ({
  id: 'archidep-following-on',
  init: (reveal: RevealApi) => {
    const own = new Map<Element, string | null>();
    const before = (): Element | null => {
      const current = reveal.getCurrentSlide();
      return current?.getAttribute('data-transition') === 'none'
        ? current.previousElementSibling
        : null;
    };

    const update = () => {
      const slide = before();
      if (slide !== null && !own.has(slide)) {
        own.set(slide, slide.getAttribute('data-transition'));
        slide.setAttribute('data-transition', 'none');
      }

      requestAnimationFrame(() =>
        requestAnimationFrame(() => {
          for (const [other, transition] of own) {
            if (other === before()) {
              continue;
            }

            own.delete(other);
            if (transition === null) {
              other.removeAttribute('data-transition');
            } else {
              other.setAttribute('data-transition', transition);
            }
          }
        })
      );
    };

    reveal.on('ready', update);
    reveal.on('slidechanged', update);
  }
});

const deck = new Reveal({
  hash: true,
  // A deck's fragments pace an explanation as it is given, which a reader of
  // the PDF is not sitting through: print each slide once, fully revealed,
  // rather than once per fragment.
  pdfSeparateFragments: false,
  markdown: {
    notesSeparator: '^\\*\\*Notes:\\*\\*',
    verticalSeparator: '^--v'
  },
  plugins: [
    Markdown,
    // Beware that the order of plugins matters! These must be after Markdown:
    // Highlight so that the code blocks it converts are highlighted, the title
    // slide so that there is a slide of the deck to mark, and the diagrams so
    // that there are diagrams in the slides to set up.
    Highlight,
    titleSlide,
    diagramsPlugin({ print: printPdfMode }),
    // Resets the logic diagrams of the current slide on R, so that their embeds
    // can do without a control bar and use its height to be larger.
    RevealLogicDiagrams,
    ...(printPdfMode || scrollMode ? [] : [cornerTitle, followingOn]),
    Notes,
    Search
  ],
  // reveal.js's own types only allow a boolean, but it also takes
  // 'separate-page', which prints the notes of each slide on a page of their
  // own.
  showNotes: getNotesMode() as boolean,
  slideNumber: 'c/t'
});

deck.initialize().then(async () => {
  document.querySelectorAll('a:not([target="_blank"])').forEach(link => {
    link.setAttribute('target', '_blank');
  });
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
