import { trackEvent } from './plausible';

document.addEventListener('click', event => {
  const target = event.target;
  if (
    !(target instanceof HTMLButtonElement) &&
    !(target instanceof HTMLLabelElement)
  ) {
    return;
  }

  if (target.classList.contains('tell-me-more')) {
    trackCalloutEvent('tell-me-more', target);
  }

  if (target.classList.contains('always-tell-me-more')) {
    const $alwaysTellMeMore = document.getElementById('always-tell-me-more');
    if ($alwaysTellMeMore === null) {
      const $newElement = document.createElement('div');
      $newElement.id = 'always-tell-me-more';
      $newElement.classList.add('hidden');
      document.body.appendChild($newElement);
      localStorage.setItem('archidep.alwaysTellMeMore', '1');
      trackCalloutEvent('always-tell-me-more', target);
    }
  }

  if (target.classList.contains('stop-telling-me-more')) {
    const $alwaysTellMeMore = document.getElementById('always-tell-me-more');
    if ($alwaysTellMeMore) {
      $alwaysTellMeMore.remove();
      localStorage.removeItem('archidep.alwaysTellMeMore');
      trackCalloutEvent('stop-telling-me-more', target);
    }

    document
      .querySelectorAll('.callout input[type="checkbox"]')
      .forEach(checkbox => {
        if (checkbox instanceof HTMLInputElement) {
          checkbox.checked = false;
        }
      });
  }
});

function trackCalloutEvent(name: string, target: HTMLElement) {
  const props = {};

  const callout =
    target.closest('.callout[data-callout]')?.getAttribute('data-callout') ??
    undefined;
  if (callout !== undefined) {
    props['callout'] = callout;
  }

  trackEvent(name, props);
}
