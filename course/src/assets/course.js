import Reveal from 'reveal.js';
import Highlight from 'reveal.js/plugin/highlight/highlight.esm.js';
import Markdown from 'reveal.js/plugin/markdown/markdown.esm.js';
import Notes from 'reveal.js/plugin/notes/notes.esm.js';
import Search from 'reveal.js/plugin/search/search.esm.js';

import 'reveal.js/dist/reveal.css';
import 'reveal.js/dist/theme/moon.css';

let deck = new Reveal({
  plugins: [Highlight, Markdown, Notes, Search],
  slideNumber: 'c/t'
});
deck.initialize();
