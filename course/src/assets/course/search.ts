import { N, O, pipe, S } from '@mobily/ts-belt';
import { isLeft } from 'fp-ts/lib/Either';
import * as t from 'io-ts';
import { debounce } from 'lodash-es';
import lunr from 'lunr';
import { match } from 'ts-pattern';

import { getValidationErrorDetails } from '../../shared/codecs/utils';
import log from '../logging';
import { isMacOs, required, toggleClass } from '../utils';
import { trackEvent } from './plausible';
import searchDialogTemplate from './search-dialog.template.html';
import searchResultTemplate from './search-result.template.html';

// What a one-letter query means, so that the shortest thing worth typing goes
// somewhere useful. Anything else is searched as it was written.
const quickSearch: Readonly<Record<string, string>> = {
  c: 'course',
  d: 'dashboard',
  h: 'home'
};

const searchElementType = t.union([
  t.literal('cheatsheet'),
  t.literal('dashboard'),
  t.literal('exercise'),
  t.literal('graded-exercise'),
  t.literal('home'),
  t.literal('slides'),
  t.literal('subject')
]);

const searchElement = t.readonly(
  t.exact(
    t.type({
      id: t.string,
      title: t.string,
      subtitle: t.string,
      url: t.string,
      type: searchElementType,
      // Never shown, and weighed more heavily than anything else: this is how a
      // page is found by words it does not say.
      extraText: t.string,
      text: t.string
    })
  )
);

type SearchElementType = t.TypeOf<typeof searchElementType>;
type SearchElement = t.TypeOf<typeof searchElement>;

type SearchResult = lunr.Index.Result & {
  readonly datum: SearchElement;
};

type SearchPosition = readonly [number, number];

const searchData = t.readonlyArray(searchElement);

// Where this build published what the dialog searches. The page says so
// outright rather than naming a file to join onto the site's mount point: the
// index carries the identifier of the build that wrote it, so its name is not
// something a script can work out.
const searchDataUrl = document.querySelector('head')?.dataset['searchDataUrl'];

// What a result of each kind is called, which is what its icon says when a
// reader hovers it.
const searchElementTypeLabels: Record<SearchElementType, string> = {
  cheatsheet: 'Cheatsheet',
  dashboard: 'Dashboard',
  exercise: 'Exercise',
  'graded-exercise': 'Graded exercise',
  home: 'Home',
  slides: 'Slides',
  subject: 'Subject'
};

/**
 * One of the site's emoji, as the page drew it.
 *
 * The dialog is markup of this script's own, so the page cannot draw an icon
 * where it goes; it leaves them all in a hidden element instead, because only
 * the build knows what an emoji file is called once it has been digested.
 */
function emoji(name: string): string {
  return (
    document.querySelector(`#search-emoji [data-emoji="${name}"]`)?.innerHTML ??
    ''
  );
}

const body = document.querySelector('body');

const testNode = document.createElement('div');
testNode.innerHTML = searchDialogTemplate;
body?.append(testNode.childNodes[0]!);

const logger = log.getLogger('search');

function getSearchButton(): HTMLElement | undefined {
  return document.getElementById('search-button') ?? undefined;
}

function getKeyboardShortcutMacOs(): HTMLElement | undefined {
  return getSearchButton()?.querySelector('kbd.macos') ?? undefined;
}

function getKeyboardShortcutNonMacOs(): HTMLElement | undefined {
  return getSearchButton()?.querySelector('kbd:not(.macos)') ?? undefined;
}

const $searchDialog = required(
  document.getElementById('search-dialog'),
  'Search dialog not found'
) as HTMLDialogElement;

const $searchIcon = required(
  $searchDialog.querySelector('.icon:not(.animate-spin)'),
  'Search icon not found'
);
const $searchInProgressIcon = required(
  $searchDialog.querySelector('.icon.animate-spin'),
  'Search in progress icon not found'
);

const $searchInput = required(
  document.getElementById('search-input'),
  'Search input not found'
) as HTMLInputElement;

const $searchNoQuery = required(
  document.getElementById('search-no-query'),
  'Search no query element not found'
);

const $searchNoResults = required(
  document.getElementById('search-no-results'),
  'Search no results element not found'
);

const $searchNoResultsIcon = required(
  document.getElementById('search-no-results-icon'),
  'Search no results icon element not found'
);

$searchNoResultsIcon.innerHTML = emoji('shrug');

const $searchResults = required(
  document.getElementById('search-results'),
  'Search results element not found'
);

const $searchResultsCount = required(
  document.getElementById('search-results-count'),
  'Search results count element not found'
);

const $searchMoreResults = required(
  document.getElementById('search-more-results'),
  'Show more results element not found'
);

let searchActive = false;
let searchResults: readonly SearchResult[] = [];

setUpSearch();

window.addEventListener('phx:page-loading-stop', () =>
  showSearchButton('live-view-page-load')
);

export function setUpSearch(): void {
  loadSearchData()
    .then(data => {
      setUpSearchListeners(buildSearchIndex(data), data);
      showSearchButton();
    })
    .catch(err => logger.error(`Failed to set up search: ${err.message}`));
}

function setUpSearchListeners(
  idx: lunr.Index,
  data: readonly SearchElement[]
): void {
  document.addEventListener('keydown', function (e) {
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
      e.preventDefault();
      showSearchDialog();
    }
  });

  $searchDialog.addEventListener('close', () => {
    $searchInput.value = '';
    renderSearchResults();
    searchActive = false;
  });

  $searchMoreResults.addEventListener('click', showMoreSearchResults);

  $searchInput.addEventListener('keyup', handleSearchInputKeyup(idx, data));
  $searchInput.addEventListener('keydown', handleSearchInputKeydown);
}

function handleSearchInputKeyup(
  idx: lunr.Index,
  data: readonly SearchElement[]
): (event: KeyboardEvent) => void {
  return event => {
    if (searchResults.length !== 0) {
      switch (event.code) {
        case 'ArrowUp':
        case 'ArrowDown':
        case 'Enter':
          event.preventDefault();
          return;
      }
    }

    const query = pipe(
      O.fromNullable($searchInput.value),
      O.map(S.trim),
      O.filter(S.isNotEmpty),
      O.toUndefined
    );

    toggleClass($searchIcon, 'hidden', query !== undefined);
    toggleClass($searchInProgressIcon, 'hidden', query === undefined);

    performSearchDebounced(idx, data);
  };
}

function handleSearchInputKeydown(event: KeyboardEvent): void {
  if (searchResults.length === 0) {
    return;
  }

  switch (event.code) {
    case 'ArrowUp':
      event.preventDefault();
      requestAnimationFrame(() => selectPreviousSearchResult());
      return;
    case 'ArrowDown':
      event.preventDefault();
      requestAnimationFrame(() => selectNextSearchResult());
      return;
    case 'Enter':
      event.preventDefault();
      goToSelectedSearchResult();
      return;
  }
}

function selectPreviousSearchResult(): void {
  const activeElement =
    $searchResults.querySelector('.search-result.active') ??
    pipe(
      O.fromNullable($searchMoreResults),
      O.filter(el => el.classList.contains('active')),
      O.toUndefined
    );
  activeElement?.classList.remove('active');

  const newActiveElement =
    pipe(
      O.fromNullable(activeElement?.previousElementSibling),
      O.filter(
        el =>
          el.classList.contains('search-result') &&
          !el.classList.contains('hidden')
      ),
      O.toUndefined
    ) ??
    pipe(
      O.fromNullable($searchMoreResults),
      O.filter(
        el =>
          activeElement?.previousElementSibling === null &&
          !el.classList.contains('hidden')
      ),
      O.toUndefined
    ) ??
    $searchResults.querySelector('.search-result:not(.hidden):has(+.hidden)') ??
    $searchResults.querySelector('.search-result:not(.hidden):last-child');
  if (newActiveElement) {
    newActiveElement.classList.add('active');
    if (!elementIsVisibleInViewport(newActiveElement)) {
      newActiveElement.scrollIntoView();
    }
  }
}

function selectNextSearchResult(): void {
  const activeElement =
    $searchResults.querySelector('.search-result.active') ??
    pipe(
      O.fromNullable($searchMoreResults),
      O.filter(el => el.classList.contains('active')),
      O.toUndefined
    );
  activeElement?.classList.remove('active');

  const newActiveElement =
    pipe(
      O.fromNullable(activeElement?.nextElementSibling),
      O.filter(
        el =>
          el.classList.contains('search-result') &&
          !el.classList.contains('hidden')
      ),
      O.toUndefined
    ) ??
    pipe(
      O.fromNullable($searchMoreResults),
      O.filter(
        el =>
          activeElement !== undefined &&
          activeElement.classList.contains('search-result') &&
          !el.classList.contains('hidden')
      ),
      O.toUndefined
    ) ??
    $searchResults.querySelector('.search-result:not(.hidden');
  if (newActiveElement) {
    newActiveElement.classList.add('active');
    if (!elementIsVisibleInViewport(newActiveElement)) {
      newActiveElement.scrollIntoView();
    }
  }
}

function goToSelectedSearchResult(): void {
  if ($searchMoreResults.classList.contains('active')) {
    showMoreSearchResults();
    return;
  }

  $searchDialog.close();

  $searchResults
    .querySelector<HTMLAnchorElement>('.search-result.active a')
    ?.click();
}

function showMoreSearchResults(): void {
  if ($searchMoreResults.classList.contains('active')) {
    $searchResults
      .querySelector('.search-result.hidden')
      ?.classList.add('active');
    $searchMoreResults.classList.remove('active');
  }

  $searchResults
    .querySelectorAll('.search-result.hidden')
    .forEach(el => el.classList.remove('hidden'));
  $searchMoreResults.classList.add('hidden');

  $searchInput.focus();
}

const performSearchDebounced = debounce(performSearch, 250, {
  leading: false,
  trailing: true
});

function performSearch(idx: lunr.Index, data: readonly SearchElement[]): void {
  toggleClass($searchIcon, 'hidden', false);
  toggleClass($searchInProgressIcon, 'hidden', true);

  if (!searchActive) {
    renderSearchResults();
    return;
  }

  const query = pipe(
    O.fromNullable($searchInput.value),
    O.map(S.trim),
    O.filter(S.isNotEmpty),
    O.toUndefined
  );
  if (query === undefined) {
    renderSearchResults();
    return;
  }

  trackSearch(query);

  const actualQuery = quickSearch[query.toLowerCase()] ?? query;

  // A hit names an entry by its identifier, and what the dialog shows is the
  // entry. One the data does not hold is dropped rather than shown empty: it can
  // only mean the index and the data came from different builds.
  const results = idx
    .search(actualQuery)
    .reduce<readonly SearchResult[]>((acc, result) => {
      const element = data.find(e => e.id === result.ref);
      return element ? [...acc, { ...result, datum: element }] : acc;
    }, []);

  renderSearchResults(query, results);
}

function renderSearchResults(
  query: string | undefined = undefined,
  results: readonly SearchResult[] = []
): void {
  searchResults = results;

  toggleClass($searchNoQuery, 'hidden', query !== undefined);

  toggleClass(
    $searchNoResults,
    'hidden',
    query === undefined || results.length !== 0
  );

  $searchResultsCount.textContent = `${results.length} result${results.length === 1 ? '' : 's'} found:`;
  toggleClass($searchResultsCount, 'hidden', results.length === 0);

  $searchResults.innerHTML = '';
  toggleClass($searchResults, 'hidden', results.length === 0);

  for (const [i, result] of results.entries()) {
    const ul = document.createElement('ul');
    ul.innerHTML = searchResultTemplate;

    const element = ul.querySelector('li')!;
    element.querySelector('.icon')!.innerHTML = match(result.datum.type)
      .with(
        'dashboard',
        () => `
        <svg
          class="size-6"
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="m21 7.5-9-5.25L3 7.5m18 0-9 5.25m9-5.25v9l-9 5.25M3 7.5l9 5.25M3 7.5v9l9 5.25m0-9v9"
          />
        </svg>
      `
      )
      .with('cheatsheet', () => emoji('memo'))
      .with('exercise', () => emoji('hammer_and_wrench'))
      .with('graded-exercise', () => emoji('trophy'))
      .with('home', () => emoji('house'))
      .with('slides', () => emoji('clapper'))
      .with('subject', () => emoji('book'))
      .exhaustive();

    element.querySelector<HTMLElement>('.icon')!.dataset['tip'] =
      searchElementTypeLabels[result.datum.type];

    const titleHtml = pipe(
      O.fromNullable(matchPositions(result, query, 'title')),
      O.map(positions => highlight(result.datum.title, positions)),
      O.getWithDefault(result.datum.title)
    );
    element.querySelector('.title')!.innerHTML = titleHtml;

    element.querySelector('.subtitle')!.textContent = result.datum.subtitle;

    const textHtml = pipe(
      O.fromNullable(matchPositions(result, query, 'text')),
      O.map(positions => highlight(result.datum.text, positions)),
      O.getWithDefault(result.datum.text)
    );

    // The same text twice: one copy is shown on a narrow screen and the other
    // on a wide one.
    element
      .querySelectorAll<HTMLElement>('.text')
      .forEach(el => (el.innerHTML = textHtml));

    element.querySelector('.link')!.setAttribute('href', result.datum.url);

    if (i >= 10) {
      element.classList.add('hidden');
    }

    $searchResults.append(element);
  }

  $searchMoreResults.innerText = `Show ${results.length - 10} more result${results.length - 10 === 1 ? '' : 's'}`;
  toggleClass($searchMoreResults, 'hidden', results.length <= 10);

  if (results.length <= 10) {
    $searchMoreResults.classList.remove('active');
  }
}

/**
 * Where in one of a result's fields the query matched, if it matched there.
 *
 * Lunr types its match metadata as a bare object, because what is in it is
 * whatever the index was built to whitelist — positions, here. So the shape is
 * stated once, in the one place that reads it, rather than at each call site.
 *
 * It is keyed by the whole query rather than by the terms the query was split
 * into, so a search of more than one word matches nothing here and is shown
 * unhighlighted. That is the behaviour, not an oversight: the point of the
 * highlight is to show *where* a single term was found in a long page.
 */
function matchPositions(
  result: SearchResult,
  query: string | undefined,
  field: 'title' | 'text'
): readonly SearchPosition[] | undefined {
  if (query === undefined) {
    return undefined;
  }

  const metadata = result.matchData.metadata as Readonly<
    Record<string, Record<string, Record<string, readonly SearchPosition[]>>>
  >;

  return metadata[query]?.[field]?.['position'];
}

function highlight(text: string, positions: readonly SearchPosition[]): string {
  const container = document.createElement('p');

  let relevantStart = pipe(
    O.fromNullable(positions[0]),
    O.map(pos => pos[0]),
    O.map(N.subtract(25)),
    O.map(i => Math.max(0, i)),
    O.getWithDefault(0)
  );

  const relevantEnd = Math.min(text.length, relevantStart + 250);

  if (relevantEnd - relevantStart < 150) {
    relevantStart = Math.max(
      0,
      relevantStart - (150 - (relevantEnd - relevantStart))
    );
  }

  let offset = relevantStart;
  for (const [start, len] of positions) {
    if (start + len > relevantEnd) {
      break;
    }

    const before = text.slice(offset, start);
    const match = text.slice(start, start + len);
    offset = start + len;

    const span = document.createElement('span');
    span.className = 'highlight';
    span.textContent = match;

    container.append(before, span);
  }

  if (offset < relevantEnd) {
    container.append(text.slice(offset, relevantEnd));
  }

  return container.innerHTML;
}

/**
 * Builds the Lunr index in the browser rather than downloading one the build
 * prepared. The serialised index is five times the size of the data it is built
 * from, and building it here costs a fraction of what downloading that would:
 * the whole course is a couple of hundred milliseconds of work, done once,
 * against megabytes that would otherwise cross the network on every first
 * search.
 *
 * The fields and their weights are the search itself: `extraText` is never
 * shown and exists only to be weighed, which is what lets a page be found by
 * words it does not say. Match positions are kept because the dialog highlights
 * what it matched.
 */
function buildSearchIndex(data: readonly SearchElement[]): lunr.Index {
  const start = Date.now();

  const idx = lunr(function () {
    this.ref('id');
    this.field('title');
    this.field('text');
    this.field('extraText', { boost: 10 });
    this.metadataWhitelist = ['position'];

    for (const datum of data) {
      this.add(datum);
    }
  });

  logger.info(
    `Built search index of ${data.length} entries in ${Date.now() - start}ms`
  );

  return idx;
}

function loadSearchData(): Promise<readonly SearchElement[]> {
  if (searchDataUrl === undefined) {
    return Promise.reject(
      new Error('The page does not say where the search data is')
    );
  }

  const start = Date.now();
  logger.debug('Downloading search data...');

  return fetch(searchDataUrl)
    .then(res => {
      if (!res.ok) {
        throw new Error(
          `Failed to load search elements with response code ${res.status}`
        );
      }

      return { downloaded: Date.now(), res };
    })
    .then(({ res, ...rest }) =>
      parseJsonWhenIdle(res).then(({ data, waited }) => ({
        ...rest,
        data,
        waited,
        parsed: Date.now()
      }))
    )
    .then(({ data, downloaded, waited, parsed }) => {
      const decodedData = searchData.decode(data);
      if (isLeft(decodedData)) {
        throw new Error(
          `Failed to decode search data because: ${getValidationErrorDetails(decodedData.left)}`
        );
      }

      const decoded = Date.now();
      const downloadTime = downloaded - start;
      const waitTime = waited - downloaded;
      const parseTime = parsed - waited;
      const decodeTime = decoded - parsed;
      const totalTime = decoded - start;
      logger.info(
        `Loaded search data in ${totalTime}ms (${downloadTime}ms dl, ${waitTime} wait, ${parseTime}ms parse, ${decodeTime}ms decode)`
      );

      return decodedData.right;
    });
}

function parseJsonWhenIdle(
  res: Response
): Promise<{ readonly data: object; readonly waited: number }> {
  return new Promise((resolve, reject) => {
    requestIdleCallback(
      () => {
        const waited = Date.now();
        res
          .json()
          .then(data => resolve({ data, waited }))
          .catch(reject);
      },
      { timeout: 2000 }
    );
  });
}

function showSearchButton(reason = 'initial'): void {
  const macOs = isMacOs();

  const macOs$ = getKeyboardShortcutMacOs();
  if (macOs$ !== undefined) {
    toggleClass(macOs$, 'sm:inline', macOs);
  }

  const nonMacOs$ = getKeyboardShortcutNonMacOs();
  if (nonMacOs$ !== undefined) {
    toggleClass(nonMacOs$, 'sm:inline', !macOs);
  }

  const searchButton$ = getSearchButton();
  if (
    searchButton$ !== undefined &&
    searchButton$.dataset['setup'] !== 'true'
  ) {
    searchButton$.addEventListener('click', () => {
      showSearchDialog();
    });

    searchButton$.classList.remove('hidden');
    searchButton$.dataset['setup'] = 'true';

    if (reason !== 'initial') {
      logger.debug(`Search button reset after ${reason}`);
    }
  }
}

function showSearchDialog(): void {
  $searchDialog.showModal();
  searchActive = true;
  setTimeout(() => $searchInput.focus(), 100);
}

function elementIsVisibleInViewport(
  el: Element,
  partiallyVisible = false
): boolean {
  const { top, left, bottom, right } = el.getBoundingClientRect();
  const { innerHeight, innerWidth } = window;
  return partiallyVisible
    ? ((top > 0 && top < innerHeight) ||
        (bottom > 0 && bottom < innerHeight)) &&
        ((left > 0 && left < innerWidth) || (right > 0 && right < innerWidth))
    : top >= 0 && left >= 0 && bottom <= innerHeight && right <= innerWidth;
}

function trackSearch(query: string): void {
  trackEvent('search', { query });
}
