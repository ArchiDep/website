import { getElementFromLinkAnchor } from './toc';

// Keeps the aside beside a page within the window before it sticks, while it is
// still below the header: how far below is what `--aside-top` tells its
// stylesheet. See `ArchiDep.CourseSite.Layout.Chrome.Article`.
//
// Its list of headings is taller than the room it has on a long page and
// scrolls on its own, so it also follows the reader: the heading being read is
// marked as the current location and scrolled into the list's view.
const $aside = document.getElementById('on-this-page-aside');
const $nav = $aside?.querySelector('nav');

// How far down the window a heading must have scrolled to be the one being
// read. A heading a link of the list jumps to stops just below the top of the
// window, well above this.
const READING_LINE = 0.25;

// How close to an edge of the list its current entry may come before the list
// is scrolled, so that the entries around it are visible too.
const NAV_MARGIN = 48;

if ($aside && $nav) {
  const entries = [...$nav.querySelectorAll('a')].flatMap(link => {
    const heading = getElementFromLinkAnchor(link);
    return heading === undefined ? [] : [{ link, heading }];
  });

  let frame: number | undefined;
  let top: number | undefined;
  let current: HTMLAnchorElement | undefined;

  const fit = (): void => {
    const next = Math.max(0, Math.round($aside.getBoundingClientRect().top));
    if (next !== top) {
      top = next;
      $aside.style.setProperty('--aside-top', `${next}px`);
    }
  };

  const follow = (): void => {
    // A narrow page shows the list above its text rather than this one.
    if ($nav.offsetParent === null) {
      return;
    }

    const next = readingEntry(entries)?.link;
    if (next === current) {
      return;
    }

    current?.removeAttribute('aria-current');
    next?.setAttribute('aria-current', 'location');
    current = next;

    if (next) {
      keepInView($nav, next);
    }
  };

  const update = (): void => {
    frame = undefined;
    fit();
    follow();
  };

  const scheduleUpdate = (): void => {
    frame ??= requestAnimationFrame(update);
  };

  update();
  window.addEventListener('scroll', scheduleUpdate, { passive: true });
  window.addEventListener('resize', scheduleUpdate);
}

type Entry = {
  readonly link: HTMLAnchorElement;
  readonly heading: Element;
};

// The last heading above the reading line, or, once the page cannot scroll any
// further, the last one in the window: the headings of the last short sections
// would never reach the line otherwise.
function readingEntry(entries: readonly Entry[]): Entry | undefined {
  const line = window.innerHeight * READING_LINE;
  const atBottom =
    window.innerHeight + window.scrollY >=
    document.documentElement.scrollHeight - 1;
  const limit = atBottom ? window.innerHeight : line;

  // The headings are listed in the order of the page, so the first one below
  // the limit ends the search.
  let reading: Entry | undefined;
  for (const entry of entries) {
    if (entry.heading.getBoundingClientRect().top > limit) {
      break;
    }

    reading = entry;
  }

  return reading;
}

// Scrolls the list itself rather than calling `scrollIntoView`, which would
// scroll the page too.
function keepInView($nav: HTMLElement, link: HTMLElement): void {
  const navBox = $nav.getBoundingClientRect();
  const linkBox = link.getBoundingClientRect();

  let delta = 0;
  if (linkBox.top < navBox.top + NAV_MARGIN) {
    delta = linkBox.top - navBox.top - NAV_MARGIN;
  } else if (linkBox.bottom > navBox.bottom - NAV_MARGIN) {
    delta = linkBox.bottom - navBox.bottom + NAV_MARGIN;
  }

  if (delta !== 0) {
    const reduceMotion = window.matchMedia(
      '(prefers-reduced-motion: reduce)'
    ).matches;
    $nav.scrollBy({ top: delta, behavior: reduceMotion ? 'auto' : 'smooth' });
  }
}
