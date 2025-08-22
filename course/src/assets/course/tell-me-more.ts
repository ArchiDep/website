import { trackEvent } from './plausible';

document.addEventListener('click', event => {
  const target = event.target;
  if (!(target instanceof HTMLButtonElement)) {
    return;
  }

  if (target.classList.contains('tell-me-more')) {
    const props = {};

    const id = target.getAttribute('for') ?? target.getAttribute('id');
    if (id !== null && id.startsWith('callout-more-')) {
      props['id'] = id;
    }

    trackEvent('tell-me-more', props);
  }

  if (target.classList.contains('always-tell-me-more')) {
    const $alwaysTellMeMore = document.getElementById('always-tell-me-more');
    if ($alwaysTellMeMore === null) {
      const $newElement = document.createElement('div');
      $newElement.id = 'always-tell-me-more';
      $newElement.classList.add('hidden');
      document.body.appendChild($newElement);
      localStorage.setItem('archidep.alwaysTellMeMore', '1');
      trackEvent('always-tell-me-more', {});
    }
  }

  if (target.classList.contains('stop-telling-me-more')) {
    const $alwaysTellMeMore = document.getElementById('always-tell-me-more');
    if ($alwaysTellMeMore) {
      $alwaysTellMeMore.remove();
      localStorage.removeItem('archidep.alwaysTellMeMore');
      trackEvent('stop-telling-me-more', {});
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
