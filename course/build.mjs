// Bundles the client-side assets of the course material site with esbuild.
//
// Usage: node build.mjs [--watch]
//
// A production build (NODE_ENV=production) is minified. Neither kind is
// type-checked: esbuild only strips types, which `npm run typecheck` checks.
import * as esbuild from 'esbuild';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const staticAssets = path.resolve(
  root,
  '..',
  'app',
  'priv',
  'static',
  'assets'
);

const production = process.env['NODE_ENV'] === 'production';
const watch = process.argv.includes('--watch');

const baseOptions = {
  absWorkingDir: root,
  alias: {
    react: 'preact/compat',
    'react-dom/test-utils': 'preact/test-utils',
    'react-dom': 'preact/compat',
    'react/jsx-runtime': 'preact/jsx-runtime'
  },
  bundle: true,
  // Entry bundles are named plainly and cache-busted by `mix phx.digest`, which
  // is the site's single asset manifest. What a bundle fetches for itself — a
  // chunk, a font a stylesheet names — never goes through that manifest, so it
  // carries a content hash of its own (esbuild's default for both).
  entryNames: '[name]',
  legalComments: 'linked',
  loader: {
    '.eot': 'file',
    '.template.html': 'text',
    '.ttf': 'file',
    '.woff': 'file',
    '.woff2': 'file'
  },
  // Several builds run side by side, so each reports through `labelled` rather
  // than esbuild's own log, whose lines do not say which build they are about.
  logLevel: 'silent',
  minify: production,
  sourcemap: true,
  target: 'es2022',
  tsconfig: 'tsconfig.assets.json'
};

// Reports each run of the build named `label`: its errors and warnings, then
// how long it took.
const labelled = label => ({
  name: 'labelled',
  setup(build) {
    let start = 0;
    build.onStart(() => {
      start = Date.now();
    });
    build.onEnd(({ errors, warnings }) => {
      for (const [kind, messages] of [
        ['error', errors],
        ['warning', warnings]
      ]) {
        if (messages.length > 0) {
          const formatted = esbuild.formatMessagesSync(messages, {
            kind,
            color: process.stderr.isTTY
          });
          console.error(`[${label}]\n${formatted.join('')}`);
        }
      }
      const outcome = errors.length > 0 ? 'failed' : 'built';
      console.log(`[${label}] ${outcome} in ${Date.now() - start} ms`);
    });
  }
});

const builds = [
  // Scripts loaded as classic scripts: each is a single file.
  {
    ...baseOptions,
    entryPoints: {
      course: './src/assets/course.ts',
      slides: './src/assets/slides.ts'
    },
    format: 'iife',
    outdir: path.join(staticAssets, 'course'),
    plugins: [labelled('course, slides')]
  },
  // Mermaid loads each kind of diagram on demand, which only an ES module
  // bundle can split into chunks, so this one is loaded with `<script
  // type="module">`. A module resolves the chunks it imports relative to its
  // own address, which is what lets the same bundle be served under an edition
  // prefix, under a mount point, and from the root of an export: an address
  // baked in here would resolve in exactly one of those.
  {
    ...baseOptions,
    entryPoints: {
      'slides-mermaid': './src/assets/slides-mermaid.ts'
    },
    format: 'esm',
    outdir: path.join(staticAssets, 'course'),
    plugins: [labelled('slides-mermaid')],
    splitting: true
  },
  // The search dialog, which the dashboard loads as well.
  {
    ...baseOptions,
    entryPoints: {
      search: './src/assets/course/search.ts'
    },
    format: 'iife',
    outdir: path.join(staticAssets, 'search'),
    plugins: [labelled('search')]
  }
];

if (watch) {
  const contexts = await Promise.all(
    builds.map(options => esbuild.context(options))
  );
  await Promise.all(contexts.map(context => context.watch()));
} else {
  // A failed build has already reported why through `labelled`.
  const results = await Promise.allSettled(
    builds.map(options => esbuild.build(options))
  );
  if (results.some(({ status }) => status === 'rejected')) {
    process.exit(1);
  }
}
