import { N, O, pipe, S } from '@mobily/ts-belt';
import { isLeft } from 'fp-ts/lib/Either';
import * as t from 'io-ts';
import { debounce } from 'lodash-es';
import lunr from 'lunr';
import { match } from 'ts-pattern';

import { getValidationErrorDetails } from '../../shared/codecs/utils';
import log from '../logging';
import { isMacOs, required, toggleClass } from '../utils';
import searchDialogTemplate from './search-dialog.template.html';
import searchResultTemplate from './search-result.template.html';

const quickSearch = {
  c: 'course',
  d: 'dashboard',
  h: 'home'
};

const searchElementType = t.union([
  t.literal('dashboard'),
  t.literal('exercise'),
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
      text: t.string
    })
  )
);

type SearchElement = t.TypeOf<typeof searchElement>;

type SearchResult = lunr.Index.Result & {
  readonly datum: SearchElement;
};

type SearchPosition = readonly [number, number];

const searchData = t.readonlyArray(searchElement);

const body = document.querySelector('body');

const testNode = document.createElement('div');
testNode.innerHTML = searchDialogTemplate;
body?.append(testNode.childNodes[0]!);

const logger = log.getLogger('search');

const $searchButton = required(
  document.getElementById('search-button'),
  'Search button not found'
);
const $searchKeyboardShortcutMacOs = required(
  $searchButton.querySelector('kbd.macos'),
  'Search keyboard shortcut for macOS not found'
);
const $searchKeyboardShortcutNonMacOs = required(
  $searchButton.querySelector('kbd:not(.macos)'),
  'Search keyboard shortcut for non-macOS not found'
);

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

export function setUpSearch(): void {
  Promise.all([loadSearchIndex(), loadSearchData()])
    .then(([idx, data]) => {
      setUpSearchListeners(idx, data);
      showSearchButton();
    })
    .catch(err => logger.error(`Failed to set up search: ${err.message}`));
}

function setUpSearchListeners(
  idx: lunr.Index,
  data: readonly SearchElement[]
): void {
  $searchButton.addEventListener('click', () => {
    showSearchDialog();
  });

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

  const actualQuery = quickSearch[query.toLowerCase()] ?? query;
  const results = idx.search(actualQuery).reduce((acc, result) => {
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
      .with('exercise', () => '🔨')
      .with('home', () => '🏠')
      .with('slides', () => '🎬')
      .with('subject', () => '📖')
      .exhaustive();

    const titleHtml = pipe(
      O.fromNullable(query),
      O.mapNullable(q => result.matchData.metadata[q]?.['title']?.['position']),
      O.map(positions => highlight(result.datum.title, positions)),
      O.getWithDefault(result.datum.title)
    );
    element.querySelector('.title')!.innerHTML = titleHtml;

    element.querySelector('.subtitle')!.textContent = result.datum.subtitle;

    const textHtml = pipe(
      O.fromNullable(query),
      O.mapNullable(q => result.matchData.metadata[q]?.['text']?.['position']),
      O.map(positions => highlight(result.datum.text, positions)),
      O.getWithDefault(result.datum.text)
    );
    element.querySelectorAll('.text').forEach(el => (el.innerHTML = textHtml));

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

function loadSearchIndex(): Promise<lunr.Index> {
  const start = Date.now();
  logger.debug('Downloading search index...');

  return fetch('/lunr.json')
    .then(res => {
      if (!res.ok) {
        throw new Error(
          `Failed to load search index with response code ${res.status}`
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
      const idx = lunr.Index.load(data);
      const built = Date.now();

      const downloadTime = downloaded - start;
      const waitTime = waited - downloaded;
      const parseTime = parsed - waited;
      const buildTime = built - parsed;
      const totalTime = built - start;

      logger.info(
        `Loaded search index in ${totalTime}ms (${downloadTime}ms dl, ${waitTime} wait, ${parseTime}ms parse, ${buildTime}ms build)`
      );

      return idx;
    });
}

function loadSearchData(): Promise<readonly SearchElement[]> {
  const start = Date.now();
  logger.debug('Downloading search data...');

  return fetch('/search.json')
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

function showSearchButton(): void {
  const macOs = isMacOs();
  toggleClass($searchKeyboardShortcutMacOs, 'sm:inline', macOs);
  toggleClass($searchKeyboardShortcutNonMacOs, 'sm:inline', !macOs);

  $searchButton.classList.remove('hidden');
}

function showSearchDialog(): void {
  $searchDialog.showModal();
  searchActive = true;
  setTimeout(() => $searchInput.focus(), 100);
}

function elementIsVisibleInViewport(el, partiallyVisible = false): boolean {
  const { top, left, bottom, right } = el.getBoundingClientRect();
  const { innerHeight, innerWidth } = window;
  return partiallyVisible
    ? ((top > 0 && top < innerHeight) ||
        (bottom > 0 && bottom < innerHeight)) &&
        ((left > 0 && left < innerWidth) || (right > 0 && right < innerWidth))
    : top >= 0 && left >= 0 && bottom <= innerHeight && right <= innerWidth;
}
