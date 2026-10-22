// Screenshots of the course material as the running dev server shows it: a
// slide, a step of the diagram on it, a diagram of a page, enlarged or not, at
// any of its steps, or a code block of a page. See "Screenshots" in
// `course/CONTRIBUTING.md`.
import { execFile } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { parseArgs, promisify } from 'node:util';
import puppeteer, { Browser, Page } from 'puppeteer';

import { courseRoot, repoRoot } from './utils/constants';
import { parseCourseManifest } from './utils/course-manifest';

const USAGE = `Usage: npm run screenshot -- <chapter> [options]

  <chapter>             A chapter's number or slug, such as 411

  --slides              The chapter's deck rather than its page
  --slide <n|text>      In the deck, the slide numbered n (as its counter
                        shows it), or whose heading contains the text;
                        repeatable
  --diagram <name>      The diagram named so (diagrams/<name>.svg): in the
                        page, a shot of it alone; in the deck, the slide
                        showing it, unless --slide names one
  --enlarged            In the page, the diagram enlarged in the lightbox
  --code <n[,n...]>     In the page, the nth code block (from 1), one shot
                        each; repeatable
  --step <n[,n...]>     With n steps reached (0: none), one shot each;
                        repeatable. Without it, a page's diagram is fully
                        drawn and a slide is as it is arrived at
  --size <w>x<h>        Window size (default 1280x800)
  --scale <n>           Device pixel ratio (default 1)
  --dark                Prefer a dark color scheme
  --settle <ms>         Wait this long before each shot, rather than for the
                        animations to end (at least 1 s)
  --timeout <s>         Seconds each shot may take at most (default 15)
  --out <dir>           Where to write the shots (default: website/tmp/
                        screenshots)
  --base-url <url>      The dev server (default http://localhost:42000)
  --edition <year>      The edition to shoot (default: the home page's)
  --skip-checks         Do not check the watchers and the generated diagrams
`;

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    slides: { type: 'boolean', default: false },
    slide: { type: 'string', multiple: true },
    diagram: { type: 'string' },
    enlarged: { type: 'boolean', default: false },
    code: { type: 'string', multiple: true },
    step: { type: 'string', multiple: true },
    size: { type: 'string', default: '1280x800' },
    scale: { type: 'string', default: '1' },
    dark: { type: 'boolean', default: false },
    settle: { type: 'string' },
    timeout: { type: 'string', default: '15' },
    out: { type: 'string' },
    'base-url': { type: 'string', default: 'http://localhost:42000' },
    edition: { type: 'string' },
    'skip-checks': { type: 'boolean', default: false },
    help: { type: 'boolean', default: false }
  },
  strict: true
});

if (values.help) {
  console.log(USAGE);
  process.exit(0);
}

const [chapter, ...extra] = positionals;
if (chapter === undefined || extra.length !== 0) {
  fail('Name exactly one chapter');
}

const sizeMatch = /^(\d+)x(\d+)$/u.exec(values.size);
const width = Number(sizeMatch?.[1]);
const height = Number(sizeMatch?.[2]);
const scale = Number(values.scale);
const timeoutMs = Number(values.timeout) * 1000;
const settleMs =
  values.settle === undefined ? undefined : Number(values.settle);
const steps: (number | undefined)[] = (values.step ?? []).flatMap(list =>
  list.split(',').map(Number)
);
const codeBlocks = (values.code ?? []).flatMap(list =>
  list.split(',').map(Number)
);

if (sizeMatch === null) {
  fail(`--size must be <width>x<height>, got ${values.size}`);
}
if (!(scale > 0)) {
  fail(`--scale must be a positive number, got ${values.scale}`);
}
if (!(timeoutMs > 0)) {
  fail(`--timeout must be a positive number of seconds, got ${values.timeout}`);
}
if (settleMs !== undefined && !(settleMs >= 0)) {
  fail(`--settle must be a number of milliseconds, got ${values.settle}`);
}
if (steps.some(step => !Number.isInteger(step) || Number(step) < 0)) {
  fail(`--step takes whole numbers, got ${values.step?.join(' ')}`);
}
if (steps.length === 0) {
  steps.push(undefined);
}
if (values.slides && values.enlarged) {
  fail('--enlarged is for a page, not a deck');
}
if (!values.slides && values.slide !== undefined) {
  fail('--slide is for a deck: add --slides');
}
if (values.enlarged && values.diagram === undefined) {
  fail('--enlarged needs --diagram');
}
if (codeBlocks.some(n => !Number.isInteger(n) || n < 1)) {
  fail(`--code takes numbers from 1, got ${values.code?.join(' ')}`);
}
if (codeBlocks.length !== 0 && values.slides) {
  fail('--code is for a page, not a deck');
}
if (
  codeBlocks.length !== 0 &&
  (values.diagram !== undefined || values.step !== undefined)
) {
  fail('--code shoots a code block, which has no diagram and no steps');
}

const baseUrl = values['base-url'];
const outDir = path.resolve(
  process.env['INIT_CWD'] ?? process.cwd(),
  values.out ?? path.join(repoRoot, 'tmp', 'screenshots')
);

await checkServer();
if (!values['skip-checks']) {
  for (const warning of await checkWatchers()) {
    console.warn(`Warning: ${warning}`);
  }
}

const doc = await findChapter(chapter);
await mkdir(outDir, { recursive: true });

interface Shot {
  /** What the shot is of, before it is taken, for its errors. */
  readonly label: string;
  /** Takes it, saying what it is named after. */
  readonly take: (page: Page) => Promise<{ name: string; image: Uint8Array }>;
}

class TimeoutError extends Error {}

const suffix = `${values.dark ? '-dark' : ''}${scale === 1 ? '' : `@${scale}x`}`;
const shots = plannedShots();

const browser = await puppeteer.launch({ timeout: timeoutMs });
let failed = false;
try {
  for (const shot of shots) {
    const errors: string[] = [];
    try {
      const { name, image } = await withTimeout(
        takeShot(browser, shot, errors)
      );
      const file = path.join(outDir, `${name}${suffix}.png`);
      await writeFile(file, image);
      console.log(file);
    } catch (err) {
      failed = true;
      console.error(
        `${shot.label}: ${err instanceof Error ? err.message : String(err)}`
      );
      // A shot that ran out of time may have left the browser stuck: the
      // shots after it would only run out of time too.
      if (err instanceof TimeoutError) {
        break;
      }
    } finally {
      for (const error of new Set(errors)) {
        console.warn(`${shot.label}: page error: ${error}`);
      }
    }
  }
} finally {
  await Promise.race([browser.close(), sleep(5000)]);
}

process.exit(failed ? 1 : 0);

async function takeShot(
  browser: Browser,
  shot: Shot,
  errors: string[]
): Promise<{ name: string; image: Uint8Array }> {
  const page = await browser.newPage();
  try {
    page.setDefaultTimeout(timeoutMs);
    // tsx keeps the names of functions by wrapping them in a `__name` helper,
    // which the functions run in the page take along but the page lacks.
    await page.evaluateOnNewDocument('globalThis.__name = f => f');
    page.on('pageerror', error =>
      errors.push(error instanceof Error ? error.message : String(error))
    );
    // A failed request is reported with its URL rather than the console's
    // message, which has none. A 401 is the page asking the dashboard who is
    // logged in, which nobody is in this browser.
    page.on('console', message => {
      if (
        message.type() === 'error' &&
        !message.text().startsWith('Failed to load resource')
      ) {
        errors.push(message.text());
      }
    });
    page.on('response', response => {
      if (response.status() >= 400 && response.status() !== 401) {
        errors.push(`${response.status()} for ${response.url()}`);
      }
    });
    await page.setViewport({ width, height, deviceScaleFactor: scale });
    await page.emulateMediaFeatures([
      { name: 'prefers-color-scheme', value: values.dark ? 'dark' : 'light' }
    ]);
    return await shot.take(page);
  } finally {
    await Promise.race([page.close(), sleep(2000)]);
  }
}

function plannedShots(): Shot[] {
  if (values.slides) {
    return (values.slide ?? [undefined]).flatMap(slide =>
      steps.map(step => deckShot(slide, step))
    );
  } else if (codeBlocks.length !== 0) {
    return codeBlocks.map(n => codeShot(n));
  }
  return steps.map(step => pageShot(step));
}

function deckShot(slide: string | undefined, step: number | undefined): Shot {
  const deckUrl = deckUrlOf();
  const stepped = step === undefined ? '' : `-step-${step}`;
  return {
    label: `${doc.num} slide ${slide ?? values.diagram ?? 1}${step === undefined ? '' : ` step ${step}`}`,
    take: async page => {
      await page.goto(deckUrl, { waitUntil: 'load' });
      await page.waitForFunction(() => window.deck?.isReady() === true);

      const reached = await page.evaluate(
        (slide, diagram, step) => {
          const deck = window.deck;
          if (deck === undefined) {
            return 'The page has no deck';
          }

          const slides = deck.getSlides();
          const headingOf = (s: HTMLElement): string =>
            s.querySelector('h1, h2, h3')?.textContent?.trim() ?? '';
          const describe = (s: HTMLElement): string =>
            `${slides.indexOf(s) + 1} (${headingOf(s) || 'no heading'})`;

          let found: HTMLElement[];
          if (slide !== null && /^\d+$/u.test(slide)) {
            const numbered = slides[Number(slide) - 1];
            found = numbered === undefined ? [] : [numbered];
          } else if (slide !== null) {
            found = slides.filter(s =>
              headingOf(s).toLowerCase().includes(slide.toLowerCase())
            );
          } else if (diagram !== null) {
            found = slides.filter(
              s =>
                s.querySelector(
                  `.diagram-figure[data-diagram="${CSS.escape(diagram)}"]`
                ) !== null
            );
          } else {
            found = slides.slice(0, 1);
          }

          const [target] = found;
          if (target === undefined) {
            return `No slide ${slide ?? `shows the diagram ${diagram}`}, among ${slides.length}`;
          } else if (found.length > 1) {
            return `Several slides match, name one with --slide: ${found.map(describe).join(', ')}`;
          }

          const count =
            Math.max(
              -1,
              ...[...target.querySelectorAll('.fragment')].map(f =>
                Number(f.getAttribute('data-fragment-index'))
              )
            ) + 1;
          if (step !== null && step > count) {
            return `Slide ${describe(target)} has ${count} steps, not ${step}`;
          }

          const { h, v } = deck.getIndices(target);
          deck.slide(h, v, step === null ? undefined : step - 1);
          return slides.indexOf(target) + 1;
        },
        slide ?? null,
        values.diagram ?? null,
        step ?? null
      );

      if (typeof reached === 'string') {
        throw new Error(reached);
      }

      await settle(page);
      return {
        name: `${doc.num}-slide-${reached}${stepped}`,
        image: await page.screenshot()
      };
    }
  };
}

function pageShot(step: number | undefined): Shot {
  const diagram = values.diagram;
  const name =
    `${doc.num}-${diagram ?? 'page'}${values.enlarged ? '-enlarged' : ''}` +
    (step === undefined ? '' : `-step-${step}`);
  return {
    label: name,
    take: async page => {
      if (doc.course_type === 'slides') {
        throw new Error(`${doc.title} is a deck: add --slides`);
      }

      await page.goto(new URL(doc.url, baseUrl).toString(), {
        waitUntil: 'load'
      });

      if (diagram === undefined) {
        await settle(page);
        return { name, image: await page.screenshot({ fullPage: true }) };
      }

      const names = await page.$$eval(
        '.diagram-figure[data-diagram]',
        figures =>
          figures.map(figure =>
            figure instanceof HTMLElement
              ? figure.dataset['diagram']
              : undefined
          )
      );
      if (!names.includes(diagram)) {
        throw new Error(
          `No diagram ${diagram} in the page, which has ${names.join(', ') || 'none'}`
        );
      }

      const selector = `.diagram-figure[data-diagram="${diagram}"]`;
      await page.waitForSelector(`${selector}[data-stepper]`);

      if (values.enlarged) {
        const enlarged = await page.$eval(selector, figure => {
          if (!figure.hasAttribute('data-enlargeable')) {
            return false;
          }
          figure.querySelector<HTMLButtonElement>('button.enlarge')?.click();
          return true;
        });
        if (!enlarged) {
          throw new Error(
            `The window is too small for the page to offer to enlarge ${diagram}: try a larger --size`
          );
        }
      }

      if (step !== undefined) {
        const error = await page.$eval(
          selector,
          async (figure, step, timeout) => {
            const counter = (): number[] | undefined =>
              /Step (\d+) of (\d+)/u
                .exec(figure.querySelector('.counter')?.textContent ?? '')
                ?.slice(1)
                .map(Number);

            figure
              .querySelector<HTMLButtonElement>('.diagram-controls .primary')
              ?.click();
            const deadline = Date.now() + timeout;
            for (;;) {
              await new Promise(resolve => setTimeout(resolve, 20));
              const [at, of] = counter() ?? [];
              if (at === undefined || of === undefined) {
                if (Date.now() > deadline) {
                  return 'The diagram has no steps to step through';
                }
                continue;
              } else if (step > of) {
                return `The diagram has ${of} steps, not ${step}`;
              } else if (at === step) {
                return null;
              }

              figure.dispatchEvent(
                new KeyboardEvent('keydown', {
                  key: at < step ? 'ArrowRight' : 'ArrowLeft',
                  bubbles: true
                })
              );
            }
          },
          step,
          timeoutMs
        );
        if (error !== null) {
          throw new Error(error);
        }
      }

      await settle(page);
      if (values.enlarged) {
        return { name, image: await page.screenshot() };
      }

      const figure = await page.$(selector);
      if (figure === null) {
        throw new Error(`No diagram ${diagram} in the page`);
      }
      return { name, image: await figure.screenshot() };
    }
  };
}

function codeShot(n: number): Shot {
  const name = `${doc.num}-code-${n}`;
  return {
    label: name,
    take: async page => {
      if (doc.course_type === 'slides') {
        throw new Error(`${doc.title} is a deck: add --slides`);
      }

      await page.goto(new URL(doc.url, baseUrl).toString(), {
        waitUntil: 'load'
      });

      const blocks = await page.$$('main pre');
      const block = blocks[n - 1];
      if (block === undefined) {
        throw new Error(
          `No code block ${n} in the page, which has ${blocks.length}`
        );
      }

      await settle(page);
      return { name, image: await block.screenshot() };
    }
  };
}

/**
 * Let the step finish moving: each shot waits at least a second, for the
 * motion script's own timers, then for the animations and transitions that end
 * within 10 s to have ended. Those that never end, such as the current along a
 * live wire, or take longer, such as reveal.js's arrow bouncing for a hundred
 * seconds, are not the step's motion and are not waited for.
 */
async function settle(page: Page): Promise<void> {
  await page.evaluate(() => document.fonts.ready);
  if (settleMs !== undefined) {
    await sleep(Math.max(settleMs, 0));
    return;
  }

  await sleep(1000);
  await page.evaluate(async budget => {
    const end = Date.now() + budget;
    for (;;) {
      const ending = document.getAnimations().filter(animation => {
        const timing = animation.effect?.getComputedTiming();
        const remaining =
          Number(timing?.endTime) - Number(timing?.localTime ?? 0);
        return animation.playState === 'running' && remaining < 10_000;
      });
      const left = end - Date.now();
      if (ending.length === 0 || left <= 0) {
        return;
      }

      await Promise.race([
        Promise.all(ending.map(animation => animation.finished.catch(() => 0))),
        new Promise(resolve => setTimeout(resolve, left))
      ]);
    }
  }, timeoutMs / 2);
}

function deckUrlOf(): string {
  if (doc.course_type === 'slides') {
    return new URL(doc.url, baseUrl).toString();
  } else if (doc.slides_pdf !== null) {
    return new URL('slides/', new URL(doc.url, baseUrl)).toString();
  }
  fail(`${doc.title} has no slides`);
}

async function checkServer(): Promise<void> {
  try {
    await fetch(baseUrl, { signal: AbortSignal.timeout(5000) });
  } catch {
    fail(
      `Nothing answers at ${baseUrl}: start the dev server (website/scripts/app)`
    );
  }
}

async function findChapter(selector: string) {
  const home = await fetchText(baseUrl);
  const edition =
    values.edition ?? /href="\/(\d{4})\/course\//u.exec(home)?.[1];
  if (edition === undefined) {
    fail(`No edition linked from ${baseUrl}: pass --edition`);
  }

  const manifestUrl = new URL(`/${edition}/archidep.json`, baseUrl).toString();
  const manifest = parseCourseManifest(
    JSON.parse(await fetchText(manifestUrl)),
    manifestUrl
  );
  const docs = manifest.sections.flatMap(section => section.docs);
  const found = docs.find(
    d =>
      String(d.num) === selector ||
      d.course_slug === selector ||
      `${d.num}-${d.course_slug}` === selector
  );
  if (found === undefined) {
    fail(`No chapter numbered or named ${selector} in ${manifestUrl}`);
  }
  return found;
}

async function fetchText(url: string): Promise<string> {
  const response = await fetch(url, { signal: AbortSignal.timeout(10_000) });
  if (!response.ok) {
    fail(`${url} answered ${response.status}`);
  }
  return response.text();
}

/**
 * What would make a shot show something other than the sources as they are:
 * a watcher not running, which leaves its assets as they were when it
 * stopped, or diagrams not generated again since their sources changed.
 */
async function checkWatchers(): Promise<string[]> {
  const run = promisify(execFile);
  const { stdout } = await run('ps', ['-axo', 'pid=,args=']);
  const processes = stdout.split('\n').flatMap(line => {
    const [, pid, args] = /^\s*(\d+)\s+(.*)$/u.exec(line) ?? [];
    return pid === undefined || args === undefined ? [] : [{ pid, args }];
  });
  const running = (...parts: string[]): boolean =>
    processes.some(({ args }) => parts.every(part => args.includes(part)));

  // webpack names its process "webpack", without its arguments: the course's
  // is the one running in the course's directory.
  const cwds = await Promise.all(
    processes
      .filter(({ args }) => /^(\S*\/)?webpack\b/u.test(args))
      .map(({ pid }) =>
        run('lsof', ['-a', '-p', pid, '-d', 'cwd', '-Fn']).then(
          ({ stdout: out }) => /^n(.*)$/mu.exec(out)?.[1],
          () => undefined
        )
      )
  );

  const warnings: string[] = [];
  if (!cwds.includes(courseRoot)) {
    warnings.push(
      'the course assets are not being built: run "npm start" in website/course'
    );
  }
  if (
    !running('tailwindcss', 'src/theme.css', '--watch') ||
    !running('tailwindcss', 'src/slides.css', '--watch')
  ) {
    warnings.push(
      'the theme is not being built: run "npm start" in website/theme'
    );
  }
  if (!running('esbuild', 'assets/js/app.js', '--watch')) {
    warnings.push(
      'the application assets are not being built: run "npm start" in website/app'
    );
  }

  try {
    await run('npm', ['run', 'diagrams', '--', '--check'], {
      cwd: courseRoot,
      timeout: 30_000
    });
  } catch {
    warnings.push(
      'the generated diagrams are out of date: run "npm run diagrams" in website/course'
    );
  }

  return warnings;
}

async function withTimeout<T>(promise: Promise<T>): Promise<T> {
  let timer: NodeJS.Timeout | undefined;
  try {
    return await Promise.race([
      promise,
      new Promise<never>((_, reject) => {
        timer = setTimeout(
          () =>
            reject(
              new TimeoutError(
                `took more than ${timeoutMs / 1000} s (--timeout)`
              )
            ),
          timeoutMs
        );
      })
    ]);
  } finally {
    clearTimeout(timer);
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function fail(message: string): never {
  console.error(`${message}\n\n${USAGE}`);
  process.exit(2);
}
