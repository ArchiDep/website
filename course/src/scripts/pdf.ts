import { G, N } from '@mobily/ts-belt';
import { isLeft } from 'fp-ts/lib/Either.js';
import * as t from 'io-ts';
import { mkdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import ProgressBar from 'progress';
import puppeteer, { Page, PDFOptions } from 'puppeteer';
import { match } from 'ts-pattern';

import { getValidationErrorDetails } from '../shared/codecs/utils';
import { courseDataFile, courseRoot } from './utils/constants';

const courseType = t.union([
  t.literal('exercise'),
  t.literal('slides'),
  t.literal('subject')
]);

const courseDocType = t.readonly(
  t.exact(
    t.type({
      title: t.string,
      num: t.number,
      course_type: courseType,
      slides: t.boolean,
      url: t.string
    })
  )
);

const courseSectionType = t.readonly(
  t.exact(
    t.type({
      title: t.string,
      docs: t.readonlyArray(courseDocType)
    })
  )
);

const courseDataType = t.readonly(
  t.exact(
    t.type({
      sections: t.readonlyArray(courseSectionType)
    })
  )
);

const pdfExportDir = path.join(courseRoot, 'pdf');

await mkdir(pdfExportDir, { recursive: true });

const courseJson = JSON.parse(await readFile(courseDataFile, 'utf-8'));
const decodedCourseData = courseDataType.decode(courseJson);
if (isLeft(decodedCourseData)) {
  throw new Error(
    `Course data in ${courseDataFile} is invalid: ${getValidationErrorDetails(decodedCourseData.left)}`
  );
}

const courseData = decodedCourseData.right;

const browser = await puppeteer.launch();
const page = await browser.newPage();

const docsToExport = courseData.sections.flatMap(section =>
  section.docs.map(doc => ({
    ...doc,
    section,
    exportCount: doc.slides ? 2 : 1
  }))
);

const progress = new ProgressBar(
  '[:bar] :current/:total :percent :elapseds :what',
  {
    width: Math.min(30, process.stdout.columns),
    total: 1 + docsToExport.map(doc => doc.exportCount).reduce(N.add, 0)
  }
);

const progressInterval = setInterval(() => progress.render(), 1000);

const baseUrl = process.argv[2] ?? `http://localhost:42000`;
progress.render({ what: 'Home' });
await exportPageToPdf(
  page,
  baseUrl,
  path.join(pdfExportDir, 'ArchiDep 000 - Course.pdf')
);
progress.tick();

for (const doc of docsToExport) {
  const docBaseUrl = `${baseUrl}${doc.url}`;
  progress.render({ what: doc.title });

  const basename = [
    `ArchiDep ${doc.num} - ${doc.section.title} - ${doc.title}`,
    match(doc.course_type)
      .with('subject', () => (doc.slides ? ' - Subject' : undefined))
      .with('slides', () => ' - Slides')
      .with('exercise', () => undefined)
      .exhaustive(),
    '.pdf'
  ]
    .filter(G.isNotNullable)
    .join('');
  const file = path.join(pdfExportDir, basename);

  const params = new URLSearchParams();
  if (doc.course_type === 'slides') {
    params.set('print-pdf', '');
    params.set('git-memoir-mode', 'visualization');
  }

  const exportUrl = `${docBaseUrl}?${params.toString()}`;
  const exportPromise =
    doc.course_type === 'slides'
      ? exportSlidesToPdf(page, exportUrl, file)
      : exportPageToPdf(page, exportUrl, file);
  await exportPromise;

  progress.tick();

  if (doc.slides) {
    params.set('print-pdf', '');
    params.set('git-memoir-mode', 'visualization');
    await exportSlidesToPdf(
      page,
      `${docBaseUrl}slides/?${params.toString()}`,
      file.replace(/Subject\.pdf$/, 'Slides.pdf')
    );

    progress.tick();
  }
}

clearInterval(progressInterval);

await browser.close();

async function exportPageToPdf(
  page: Page,
  url: string,
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
  url: string,
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
  url: string,
  options: PDFOptions
): Promise<void> {
  await page.evaluateOnNewDocument(() => {
    localStorage.setItem('plausible_ignore', 'true');
  });

  await page.goto(url, {
    waitUntil: 'networkidle2'
  });

  await page.bringToFront();

  await page.pdf(options);
}
