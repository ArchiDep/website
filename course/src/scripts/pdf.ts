import { N } from '@mobily/ts-belt';
import { mkdir, rm } from 'node:fs/promises';
import path from 'node:path';
import { parseArgs } from 'node:util';
import ProgressBar from 'progress';
import puppeteer, { Page, PDFOptions } from 'puppeteer';

import {
  findCourseManifest,
  readCourseManifest
} from './utils/course-manifest';
import { serveDirectory, StaticServer } from './utils/static-server';

const { values } = parseArgs({
  allowPositionals: false,
  options: {
    build: { type: 'string' },
    output: { type: 'string' },
    manifest: { type: 'string' },
    'base-url': { type: 'string' },
    port: { type: 'string' }
  },
  strict: true
});

// npm runs a workspace script from that workspace's directory, so a relative
// path has to be read against the directory the command was typed in for the
// script to be pointed anywhere at all.
const invokedFrom = process.env['INIT_CWD'] ?? process.cwd();
const resolvePath = (value: string): string => path.resolve(invokedFrom, value);

const buildDir =
  values.build === undefined ? undefined : resolvePath(values.build);
const baseUrlArg = values['base-url'];

if (values.output === undefined) {
  throw new Error('Pass --output <dir> to say where the PDFs go');
}

const port = values.port === undefined ? 0 : Number.parseInt(values.port, 10);
if (!Number.isInteger(port) || port < 0 || port > 65535) {
  throw new Error(`--port must be a port number, got ${values.port}`);
}

let manifestFile: string;
if (values.manifest !== undefined) {
  manifestFile = resolvePath(values.manifest);
} else if (buildDir !== undefined) {
  manifestFile = await findCourseManifest(buildDir);
} else {
  throw new Error(
    'Pass --build <dir> to find the manifest in, or --manifest <file> to name it'
  );
}

const outputDir = resolvePath(values.output);
if (outputDir === path.parse(outputDir).root) {
  throw new Error(`Refusing to empty ${outputDir}`);
}
if (
  buildDir !== undefined &&
  (buildDir === outputDir || buildDir.startsWith(outputDir + path.sep))
) {
  throw new Error(
    `Refusing to empty ${outputDir}, which holds the build being printed`
  );
}

const courseData = await readCourseManifest(manifestFile);

await rm(outputDir, { recursive: true, force: true });
await mkdir(outputDir, { recursive: true });

// Nothing outside this process has to be running: the pages are static files
// and their links are whatever the build baked into them, so where they are
// served from cannot reach what is printed.
let baseUrl: string;
let server: StaticServer | undefined;
if (baseUrlArg !== undefined) {
  baseUrl = baseUrlArg;
  server = undefined;
} else if (buildDir !== undefined) {
  server = await serveDirectory(buildDir, port);
  baseUrl = server.baseUrl;
} else {
  throw new Error(
    'Pass --build <dir> to serve, or --base-url <url> to print a site that is already being served'
  );
}

const docsToExport = courseData.sections.flatMap(section => section.docs);

const progress = new ProgressBar(
  '[:bar] :current/:total :percent :elapseds :what',
  {
    width: Math.min(30, process.stdout.columns),
    total:
      1 +
      docsToExport
        .map(doc => (doc.slides_pdf === null ? 1 : 2))
        .reduce(N.add, 0) +
      courseData.cheatsheets.length
  }
);

const progressInterval = setInterval(() => progress.render(), 1000);
const browser = await puppeteer.launch();

try {
  const page = await browser.newPage();
  await page.evaluateOnNewDocument(() => {
    localStorage.setItem('plausible_ignore', 'true');
  });

  progress.render({ what: 'Home' });
  await exportPageToPdf(
    page,
    new URL(courseData.home.url, baseUrl),
    path.join(outputDir, courseData.home.pdf)
  );
  progress.tick();

  for (const doc of docsToExport) {
    const docUrl = new URL(doc.url, baseUrl);
    progress.render({ what: doc.title });

    const params = new URLSearchParams();
    if (doc.course_type === 'slides') {
      params.set('print-pdf', '');
      params.set('git-memoir-mode', 'visualization');
    } else {
      params.set('git-memoir-force', 'true');
      params.set('git-memoir-mode', 'visualization');
    }

    const exportUrl = new URL(docUrl);
    exportUrl.search = params.toString();
    const file = path.join(outputDir, doc.pdf);

    await (doc.course_type === 'slides'
      ? exportSlidesToPdf(page, exportUrl, file)
      : exportPageToPdf(page, exportUrl, file));

    progress.tick();

    if (doc.slides_pdf !== null) {
      params.set('print-pdf', '');
      params.set('git-memoir-mode', 'visualization');

      const slidesUrl = new URL('slides/', docUrl);
      slidesUrl.search = params.toString();

      await exportSlidesToPdf(
        page,
        slidesUrl,
        path.join(outputDir, doc.slides_pdf)
      );

      progress.tick();
    }
  }

  for (const cheatsheet of courseData.cheatsheets) {
    progress.render({ what: cheatsheet.title });

    await exportPageToPdf(
      page,
      new URL(cheatsheet.url, baseUrl),
      path.join(outputDir, cheatsheet.pdf)
    );

    progress.tick();
  }
} finally {
  clearInterval(progressInterval);
  await browser.close();
  await server?.close();
}

async function exportPageToPdf(
  page: Page,
  url: URL,
  file: string
): Promise<void> {
  await exportToPdf(page, url, {
    format: 'A4',
    margin: {
      top: '1cm',
      right: '1cm',
      bottom: '1cm',
      left: '1cm'
    },
    path: file,
    waitForFonts: true
  });
}

async function exportSlidesToPdf(
  page: Page,
  url: URL,
  file: string
): Promise<void> {
  await exportToPdf(page, url, {
    path: file,
    preferCSSPageSize: true,
    printBackground: true,
    waitForFonts: true
  });
}

async function exportToPdf(
  page: Page,
  url: URL,
  options: PDFOptions
): Promise<void> {
  await page.goto(url.toString(), {
    waitUntil: 'networkidle2'
  });

  await page.bringToFront();

  await page.pdf(options);
}
