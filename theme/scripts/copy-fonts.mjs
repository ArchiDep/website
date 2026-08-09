// Copy the fonts the site is set in into the static assets served at
// /assets/fonts. They are plain files rather than a Tailwind input, so the CSS
// build ignores them and this script puts them where every build expects to
// find them.
//
// What to copy is read out of `src/fonts.css` rather than listed here, so that
// the stylesheet naming a face and the directory holding it cannot drift: a
// name it writes that no package answers for stops the build here instead of
// 404ing in a browser.

import { createRequire } from 'node:module';
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync
} from 'node:fs';
import { pathToFileURL } from 'node:url';

const require = createRequire(import.meta.url);

// The packages the faces come from. Google Fonts publishes each family as one
// of these, so a family is added by installing its package and declaring its
// faces in the stylesheet.
const packages = [
  '@fontsource/pt-sans',
  '@fontsource/fjalla-one',
  '@fontsource-variable/bitcount-prop-single'
];

const stylesheet = new URL('../src/fonts.css', import.meta.url);
const destination = new URL(
  '../../app/priv/static/assets/fonts/',
  import.meta.url
);

const directories = packages.map(
  name =>
    new URL('./files/', pathToFileURL(require.resolve(`${name}/package.json`)))
);

const css = readFileSync(stylesheet, 'utf8');
const files = [
  ...new Set(
    [...css.matchAll(/url\(\s*['"]?\.\.\/fonts\/([^'")\s]+)['"]?\s*\)/gu)].map(
      match => match[1]
    )
  )
];

if (files.length === 0) {
  throw new Error(`${stylesheet.pathname} names no font file to publish`);
}

const sources = files.map(file => {
  const source = directories
    .map(directory => new URL(file, directory))
    .find(candidate => existsSync(candidate));

  if (!source) {
    throw new Error(
      `${stylesheet.pathname} names "${file}", which none of ${packages.join(', ')} provides`
    );
  }

  return [source, new URL(file, destination)];
});

// Emptied rather than written over, so that a face the stylesheet stops naming
// stops being published with it.
rmSync(destination, { force: true, recursive: true });
mkdirSync(destination, { recursive: true });

for (const [source, target] of sources) {
  copyFileSync(source, target);
}
