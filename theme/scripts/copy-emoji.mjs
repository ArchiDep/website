// Copy the site's emoji SVGs into the static assets served at /assets/emoji.
// They are plain files rather than a Tailwind input, so the CSS build ignores
// them and this script puts them where every build expects to find them.

import { cpSync } from 'node:fs';

const source = new URL('../emoji/', import.meta.url);
const destination = new URL(
  '../../app/priv/static/assets/emoji/',
  import.meta.url
);

cpSync(source, destination, {
  recursive: true,
  filter: path => !path.endsWith('.md')
});
