// Fails unless the built course assets address what they fetch for themselves
// relatively. See "Build Output & Asset URLs" in `course/CONTRIBUTING.md`.
import { readFile } from 'node:fs/promises';
import path from 'node:path';

import { destDir } from './utils/constants';

const assetsDir = path.join(destDir, 'assets', 'course');

// The fonts and images the bundled stylesheet names, inlined ones aside.
const slidesCss = await readFile(path.join(assetsDir, 'slides.css'), 'utf8');
const cssUrls = [...slidesCss.matchAll(/url\(\s*["']?([^"')]+)/gu)].flatMap(
  ([, url]) => (url === undefined || url.startsWith('data:') ? [] : [url])
);

const problems = cssUrls
  .filter(url => url.startsWith('/') || /^[a-z]+:/u.test(url))
  .map(url => `slides.css names ${url}`);

if (problems.length > 0) {
  console.error('The course assets do not address themselves relatively:');
  for (const problem of problems) {
    console.error(`  ${problem}`);
  }
  process.exit(1);
}
