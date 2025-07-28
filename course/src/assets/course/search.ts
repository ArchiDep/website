import { O, pipe, S } from '@mobily/ts-belt';
import * as t from 'io-ts';
import lunr from 'lunr';
import { isLeft } from 'fp-ts/lib/Either';
import { debounce } from 'lodash-es';
import { match } from 'ts-pattern';

import { getValidationErrorDetails } from '../../shared/codecs/utils';
import log from '../logging';
import { isMacOs, required, toggleClass } from '../utils';

const searchElementType = t.union([
  t.literal('exercise'),
  t.literal('slides'),
  t.literal('subject')
]);

const searchElement = t.readonly(
  t.exact(
    t.type({
      id: t.string,
      title: t.string,
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

const searchData = t.readonlyArray(searchElement);

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

const $searchResultSample = required(
  document.getElementById('search-result-sample'),
  'Search result sample element not found'
) as HTMLTemplateElement;

let searchActive = false;
let searchResults: readonly SearchResult[] = [];

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

  $searchDialog.addEventListener('close', () => ($searchInput.value = ''));

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
      selectPreviousSearchResult();
      return;
    case 'ArrowDown':
      event.preventDefault();
      selectNextSearchResult();
      return;
    case 'Enter':
      event.preventDefault();
      goToSelectedSearchResult();
      return;
  }
}

function selectPreviousSearchResult(): void {
  const activeElement = $searchResults.querySelector('.search-result.active');
  activeElement?.classList.remove('active');
  (
    activeElement?.previousElementSibling ??
    $searchResults.querySelector('.search-result:last-child')
  )?.classList.add('active');
}

function selectNextSearchResult(): void {
  const activeElement = $searchResults.querySelector('.search-result.active');
  activeElement?.classList.remove('active');
  (
    activeElement?.nextElementSibling ??
    $searchResults.querySelector('.search-result')
  )?.classList.add('active');
}

function goToSelectedSearchResult(): void {
  $searchResults
    .querySelector<HTMLAnchorElement>('.search-result.active a')
    ?.click();
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

  const results = idx
    .search(query)
    .slice(0, 10)
    .reduce((acc, result) => {
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

  for (const result of results) {
    const element = $searchResultSample.content.cloneNode(true) as HTMLElement;
    element.querySelector('.icon')!.textContent = match(result.datum.type)
      .with('exercise', () => '🔨')
      .with('slides', () => '🎬')
      .with('subject', () => '📖')
      .exhaustive();
    element.querySelector('.title')!.textContent = result.datum.title;
    element.querySelector('.subtitle')!.textContent = result.datum.text.slice(
      0,
      50
    );
    element.querySelector('.link')!.setAttribute('href', result.datum.url);
    $searchResults.append(element);
  }
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
