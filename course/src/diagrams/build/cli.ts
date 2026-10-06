// Brings every diagram up to date: copies the shared parts into each drawing,
// then generates the partial that pages and decks include.
//
//     npm run diagrams              # write what is out of date
//     npm run diagrams -- --check   # only report it, and fail
//     npm run diagrams -- --dir <d> # another directory of diagrams
import { readdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { parseArgs } from 'node:util';
import { pathToFileURL } from 'node:url';

import type { DiagramDefinition } from './builder';
import { generate, sync } from './generate';

const COURSE_DIR = path.resolve(import.meta.dirname, '..', '..', '..');

const { values } = parseArgs({
  options: {
    check: { type: 'boolean', default: false },
    dir: { type: 'string', default: path.join(COURSE_DIR, 'diagrams') }
  }
});

const dir = path.resolve(values.dir);
const check = values.check;

const shared = await readFile(path.join(dir, 'shared.svg'), 'utf8');
const motion = await readFile(
  path.join(COURSE_DIR, 'src', 'diagrams', 'diagram.css'),
  'utf8'
);

// A diagram is a drawing with a definition of its steps beside it.
const names = (await readdir(dir))
  .filter(file => file.endsWith('.ts') && !file.endsWith('.d.ts'))
  .map(file => file.slice(0, -'.ts'.length))
  .sort();

const stale: string[] = [];

for (const name of names) {
  const svgFile = path.join(dir, `${name}.svg`);
  const source = await readFile(svgFile, 'utf8');
  const svg = sync(source, shared, `${name}.svg`);
  await update(svgFile, source, svg);

  const module: unknown = await import(
    pathToFileURL(path.join(dir, `${name}.ts`)).href
  );
  const definition = definitionOf(module, name);

  const partialFile = path.join(dir, `${name}.html`);
  const partial = generate({ name, svg, definition, motion });
  await update(partialFile, await readIfExists(partialFile), partial);
}

if (check && stale.length > 0) {
  console.error(
    `Out of date, run "npm run diagrams" to update:\n${stale.map(f => `  ${f}`).join('\n')}`
  );
  process.exitCode = 1;
} else if (!check) {
  console.log(
    stale.length > 0
      ? `Updated:\n${stale.map(f => `  ${f}`).join('\n')}`
      : 'Every diagram is up to date.'
  );
}

async function update(
  file: string,
  current: string | null,
  wanted: string
): Promise<void> {
  if (current === wanted) {
    return;
  }

  stale.push(path.relative(process.cwd(), file));
  if (!check) {
    await writeFile(file, wanted, 'utf8');
  }
}

async function readIfExists(file: string): Promise<string | null> {
  try {
    return await readFile(file, 'utf8');
  } catch (error) {
    if (error instanceof Error && 'code' in error && error.code === 'ENOENT') {
      return null;
    }

    throw error;
  }
}

function definitionOf(module: unknown, name: string): DiagramDefinition {
  const definition =
    typeof module === 'object' && module !== null && 'default' in module
      ? module.default
      : undefined;
  if (
    typeof definition !== 'object' ||
    definition === null ||
    !('steps' in definition) ||
    !('captions' in definition)
  ) {
    throw new Error(
      `${name}.ts must export the diagram's definition as its default export`
    );
  }

  return definition as DiagramDefinition;
}
