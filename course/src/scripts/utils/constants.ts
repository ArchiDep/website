import { pipe } from '@mobily/ts-belt';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const courseRoot = pipe(
  import.meta.url,
  fileURLToPath,
  path.dirname,
  path.dirname,
  path.dirname,
  path.dirname
);

export const repoRoot = path.dirname(courseRoot);
export const destDir = path.resolve(repoRoot, 'app', 'priv', 'static');
export const courseDataFile = path.join(destDir, 'archidep.json');
export const courseSearchFile = path.join(destDir, 'search.json');
export const courseIndexFile = path.join(destDir, 'lunr.json');
