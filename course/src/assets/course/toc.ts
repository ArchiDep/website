import { O, pipe, S } from '@mobily/ts-belt';

// Configure smooth scrolling for links in the table of contents
document.querySelectorAll('nav.toc a').forEach(link => {
  const $el = getElementFromLinkAnchor(link);
  if ($el === undefined) {
    return;
  }

  link.addEventListener('click', event => {
    event.preventDefault();
    smoothScrollALittleAbove($el);
  });
});

function getElementFromLinkAnchor(link: Element): Element | undefined {
  return pipe(
    O.fromNullable(link.getAttribute('href')),
    O.map(S.sliceToEnd(1)),
    O.mapNullable(id => document.getElementById(id)),
    O.toUndefined
  );
}

function smoothScrollALittleAbove(el: Element): void {
  const y = el.getBoundingClientRect().top + window.scrollY - 10;
  window.scrollTo({ top: y, behavior: 'smooth' });
  window.history.pushState({}, '', `#${el.id}`);
}
